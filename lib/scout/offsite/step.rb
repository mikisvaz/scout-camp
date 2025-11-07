require_relative 'ssh'
require_relative 'sync'
require 'scout/workflow/step'

module OffsiteStep

  extend Annotation
  annotation :server, :workflow_name, :clean_id, :batch

  def inputs_directory
    @inputs_directory ||= begin
                            if provided_inputs && provided_inputs.any?
                              file = ".scout/tmp/step_inputs/#{workflow}/#{task_name}/#{name}"
                              TmpFile.with_path do |inputs_dir|
                                save_inputs(inputs_dir)
                                SSHLine.rsync(inputs_dir, file, target: server, directory: inputs_dir.directory?)
                              end
                              file
                            end
                          end
  end

  def workflow_name
    @workflow_name || workflow.to_s
  end

  def offsite_job_ssh(script)
    parts = []
    parts << <<~EOF.strip
wf = Workflow.require_workflow "#{workflow_name}";
    EOF

    rec_dependencies.collect{|d| d.workflow }.compact.uniq.each do |other_workflow|
      next if workflow_name == other_workflow.to_s
      parts << <<~EOF.strip
Workflow.require_workflow "#{other_workflow}" rescue nil;
      EOF
    end

    if inputs_directory
      parts << <<~EOF.strip
job = wf.job(:#{task_name}, "#{clean_name}", :load_inputs => "#{inputs_directory}");
      EOF
    else
      parts << <<~EOF.strip
job = wf.job(:#{task_name}, "#{clean_name}");
      EOF
    end

    parts << script


    SSHLine.scout server, parts * "\n"
  end

  def offsite_path
    @path = offsite_job_ssh <<~EOF
      job.path.identify
    EOF
  end

  def info
    info = @info ||= offsite_job_ssh <<~EOF
    info = Open.exists?(job.info_file) ? job.info : {}
    info[:running] = true if job.running?
    info
    EOF

    @info = nil unless %w(done aborted error).include?(info[:status].to_s)

    info
  end

  def done?
    status == :done
  end

  def orchestrate_batch
    bundle_files = offsite_job_ssh <<~EOF
    require 'rbbt/hpc'
    rules = Workflow::Orchestrator.load_rules_for_job(job)
    Workflow::Scheduler.produce(job, rules)
    job.join
    job.bundle_files
    EOF
    SSHLine.sync(bundle_files, source: server)
  end

  def exec(noload)
    bundle_files = offsite_job_ssh <<~EOF
    Workflow.produce(job)
    job.join
    job.bundle_files
    EOF
    SSHLine.sync(bundle_files, source: server)
    noload ? self.path : self.load
  end

  def run(noload=false)
    if batch
      orchestrate_batch
      noload ? self.path : self.load
    else
      exec(noload)
    end
  end
end
