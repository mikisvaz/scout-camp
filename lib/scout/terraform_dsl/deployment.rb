require_relative 'util'
require 'open3'

class TerraformDSL

  # Manage Terraform deployments
  class Deployment

    # Exception running terraform command
    class TerraformException < StandardError; end

    # Run a terraform command returning the STDOUT as a String.
    # Forwards STDERR of the process
    #
    # @param cmd [String] terraform command to run (not including terraform
    #   command name)
    # @return [String] STDOUT of the process
    def self.run(cmd)
      Open3.popen3("terraform #{cmd}") do |stdin, stdout, stderr, wait_thr|
        TerraformDSL.log "Running: terraform #{cmd}", wait_thr.pid
        stdin.close
        stderr_thr = Thread.new do
          while (line = stderr.gets)
            TerraformDSL.log line, wait_thr.pid
          end
        end
        out = stdout.read
        exit_status = wait_thr.value
        raise TerraformException, out.split(/Error:\s*/m).last if exit_status != 0

        stderr_thr.join
        out
      end
    end

    # Run a terraform command loging STDERR and STDOUT of the process to STDERR
    # and to a log file.
    #
    # @param cmd [String] terraform command to run (not including terraform
    #   command name)
    # @param log_file [String] path to the log file (optional)
    def self.run_log(cmd, log_file = nil)
      log_io = Open.open(log_file, mode: 'a') if log_file
      log_io.sync = true if log_io
      Open3.popen3("terraform #{cmd}") do |stdin, stdout, stderr, wait_thr|
        TerraformDSL.log "Running: terraform #{cmd}", wait_thr.pid
        stdin.close
        wait_thr.pid
        stdin.close
        stderr_thr = Thread.new do
          while (line = stderr.gets)
            TerraformDSL.log line, [wait_thr.pid, :STDERR] * " - "
            log_io.puts "[#{Time.now} - STDERR]: " + line if log_io
          end
        end
        stdout_thr = Thread.new do
          while (line = stdout.gets)
            TerraformDSL.log line, [wait_thr.pid, :STDOUT] * " - "
            log_io.puts "[#{Time.now} - STDOUT]: " + line if log_io
          end
        end
        exit_status = wait_thr.value

        stderr_thr.join
        stdout_thr.join
        log_io.close if log_io

        if exit_status != 0
          log_io.close if log_io
          log_txt = Open.read(log_file, :encoding => "UTF-8")
          error_msg = log_txt.split(/Error:/).last
          error_msg = error_msg.split("\n").collect{|e| e.sub(/.*? STD...\]:\s*/,'') } * "\n"
          raise TerraformException, error_msg
        end

      end
      nil
    end

    attr_accessor :directory

    # Create a new deployment on a given directory.
    # Templates and modules will reside on the directory and can be used by
    # terraform
    #
    # @param config_dir [String] path to the deployment directory
    def initialize(config_dir)
      @directory = (Path === config_dir) ? config_dir.find : config_dir

      @init = false
    end

    # @return [String] File where the terraform plan will be stored
    def plan_file
      @directory['main.plan']
    end

    # @return [String] File where the logs will be stored
    def log_file
      @directory.log
    end

    # Initialize deployment @directory with all the templates and modules.
    # Sets @init to true and @planned to false. Removes plan_file if present
    def init
      Misc.in_dir @directory.find do
        Deployment.run_log 'init', log_file
      end
      Open.rm plan_file if Open.exist?(plan_file)
      @init = true
      @planned = false
      nil
    end

    # Update changes on a terraform deployment by running init, plan, and apply
    def update
      init
      plan
      apply
    end

    # Validate a terraform deployment. Runs init if required
    def validate
      init unless @init
      Misc.in_dir @directory do
        Deployment.run('validate')
      end
    end

    # Plan a terraform deployment and save it in #plan_file. Runs init if
    # required. Saves the time in @planned
    def plan
      init unless @init
      Misc.in_dir @directory.find do
        Deployment.run_log("plan -out #{plan_file}", log_file)
      end
      @planned = Time.now
    end

    # Applies a terraform deployment by running the plan_file.
    def apply
      plan unless @planned
      Misc.in_dir @directory do
        Deployment.run_log("apply -auto-approve #{plan_file}", log_file)
      end
    end

    def refresh
      plan unless @planned
      Misc.in_dir @directory do
        Deployment.run_log('refresh', log_file)
      end
    end

    # Lists all provisioned elements
    #
    # @return [Array] with names of provisioned elements
    def provisioned_elements
      Misc.in_dir @directory do
        begin
          Deployment.run('state list').split("\n")
        rescue StandardError
          []
        end
      end
    end

    # Lists all provisioned elements
    #
    # @return [Hash] with templates organized by module type
    def templates
      elements = {}
      @directory.glob("*.tf").each do |file|
        if m = File.basename(file).match(/^([^.]+)\.([^.]+)\.tf/)
          elements[m[1]] ||= []
          elements[m[1]] << m[2]
        end
      end
      elements
    end


    # Return the state of a provisioned element
    #
    # @return [String] state of the element in the original terraform format
    def element_state(element)
      Misc.in_dir @directory do
        Deployment.run("state show '#{element}'")
      end
    end

    # Destroys a provision
    def destroy
      Misc.in_dir @directory do
        Deployment.run_log('destroy -auto-approve', log_file)
      end
    end

    # Returns the outputs available for a current deployment
    #
    # @return [Hash] containg the output names (module.variable_name) and their values
    def outputs
      outputs = {}

      Misc.in_dir @directory do
        output_info = JSON.parse(Deployment.run('output -json'))

        output_info.each do |output, info|
          outputs[output] = info['value']
        end
      end

      outputs
    end

    # Returns the value of an output for a given module in the current
    # deployment
    #
    # @param name [String] name of the module
    # @param output [String] name of the module output variable
    #
    # @return [Hash] containg the output names and their values
    def output(name, output)
      name = name.name if defined?(TerraformDSL::Module) && name.is_a?(TerraformDSL::Module)

      outputs[[name, output].join('_')]
    end

    # Apply a deployment, run a block of code, and destroy the deployment
    # afterwards
    #
    # @return whatever the block returns
    def with_deployment
      begin
        apply
        yield
      ensure
        destroy
      end
    end

    # Delete an element of a deployment. Removes the definition file and the
    # output file
    #
    # @param element [String] name of the element to destroy
    def delete(element)
      [element + '.tf', element + '.output.tf'].each do |file|
        path = @directory[file]
        Open.rm path
      end
    end

    def bundle(file)
      raise TerraformException, "Target bundle file is nil" if file.nil?
      TerraformDSL.log "Bundle #{@directory} in #{file}", "TerraformDSL::Deployment"
      Misc.in_dir @directory do
        cmd = "tar cvfz '#{file}' *"
        cmd += ' *.lock.hcl' if Dir.glob('*.lock.hcl').any?
        cmd += ' > /dev/null'
        system(cmd)
      end
    end

    def with_bundle(&block)
      name = 'deployment-bundle-tmp_' + rand(100000).to_s + '.tar.gz'
      TmpFile.with_file nil, extension: 'deployment_bundle' do |tmpfile|
        bundle(file)
        yield file
      end
    end

    def self.load(file, directory = nil)
      directory ||= WORK_DIR[TerraformDSL.obj2digest(file)]
      TerraformDSL.log "Load #{file} bundle into #{directory}", "TerraformDSL::Deployment"
      Misc.in_dir directory do
        `tar xvfz #{file}`
      end
      deployment = TerraformDSL::Deployment.new directory
      deployment.refresh
      deployment
    end

  end

end
