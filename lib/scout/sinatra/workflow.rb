require 'sinatra'
require_relative 'base'
require_relative 'knowledge_base'

module SinatraScoutWorkflow
  def self.registered(app)
    app.register SinatraScoutKnowledgeBase

    app.set :registered_workflows, {}

    # helpers for REST-style responses & params
    app.helpers do
      # prepare task inputs: read keys from provided task_info[:inputs]
      def consume_task_parameters_for(workflow, task, params_hash)
        task_info = workflow.task_info(task.to_sym)
        inputs = {}
        task_info[:inputs].each do |k|
          v = params_hash[k.to_s]
          inputs[k.to_sym] = v unless v.nil?
          # accept file parts named "#{k}__param_file" (Rack file upload hash)
          if params_hash["#{k}__param_file"]
            inputs["#{k}__param_file"] = params_hash["#{k}__param_file"]
          end
        end
        inputs
      end

      def workflow_render(workflow, template, params = {})
        params[:workflow] = workflow
        case template
        when :tasks
          render_template('tasks', params)
        when Symbol, String
          render_template("#{workflow}/#{template}", params.merge(task: template))
        when Step
          step = template
          task_name = step.task_name
          render_template("#{workflow}/#{template}", params.merge(task: template))
        end
      end
    end

    # expose method to register a workflow at runtime
    app.define_singleton_method(:add_workflow) do |workflow, opts = {}|
      name = workflow.to_s.split('::').last
      settings.registered_workflows[name] = workflow
      settings.knowledge_base = workflow.knowledge_base if workflow.knowledge_base
      ScoutRender.prepend_path name, workflow.libdir

      # GET /<workflow> - exports
      app.get "/#{name}" do
        case _format
        when :json
          exports = {
            stream: workflow.stream_exports,
            exec: workflow.exec_exports,
            synchronous: workflow.synchronous_exports,
            asynchronous: workflow.asynchronous_exports,
          }
          exported_tasks = exports.values.flatten.compact.uniq

          info = exported_tasks.inject({}) do |acc,tname|
            acc[tname] = workflow.task_info(tname)
            acc[tname][:export] = exports.find{|type,tasks| tasks.include?(tname) }.first
            acc
          end

          json_halt 200, info
        else
          workflow_render(workflow, :tasks)
          render_template('tasks', params.merge(workflow: workflow))
        end
      end
      
      # GET /<workflow> - exports
      app.get "/#{name}/:task" do
        task = consume_parameter(:task)
        case _format
        when :json
          json_halt 200, workflow.task_info(task)
        else
          render_template('tasks', params.merge(workflow: workflow))
        end
      end

      # GET /<workflow>/documentation
      app.get "/#{name}/documentation" do
        fmt = requested_format
        if fmt == :json
          content_type 'application/json'
          (workflow.documentation || {}).to_json
        else
          status 406
          "HTML not implemented by REST component"
        end
      end

      # GET /<workflow>/:task/info
      app.get "/#{name}/:task/info" do
        task = consume_parameter(:task)
        unless workflow.tasks.include?(task.to_sym)
          return json_halt(404, message: "Task not found")
        end
        fmt = requested_format
        if fmt == :json
          content_type 'application/json'
          workflow.task_info(task.to_sym).to_json
        else
          status 406
          "HTML not implemented by REST component"
        end
      end

      # GET /<workflow>/:task/dependencies
      app.get "/#{name}/:task/dependencies" do
        task = consume_parameter(:task)
        unless workflow.tasks.include?(task.to_sym)
          return json_halt(404, message: "Task not found")
        end
        fmt = requested_format
        if fmt == :json
          content_type 'application/json'
          deps = workflow.task_dependencies[task.to_sym]
          (deps || []).to_json
        else
          status 406
          "HTML not implemented by REST component"
        end
      end

      app.get "/#{name}/:task" do
        task = consume_parameter(:task)
        unless workflow.tasks.include?(task.to_sym)
          return json_halt(404, message: "Task not found")
        end

        render_template('form', workflow: workflow, task: task)
      end

      # POST /<workflow>/:task  -> create a job (REST returns job metadata)
      app.post "/#{name}/:task" do
        task = consume_parameter(:task)
        jobname = consume_parameter(:jobname)
        unless workflow.tasks.include?(task.to_sym)
          return json_halt(404, message: "Task not found")
        end

        # collect inputs from params (leave raw values and file hashes as-is)
        inputs = consume_task_parameters_for(workflow, task, params)

        # create job via workflow.job(task, jobname, inputs)
        # the workflow implementation is expected to provide `job`
        begin
          job = workflow.job(task.to_sym, jobname, inputs)
        rescue Exception => e
          return json_halt(500, message: "Failed to create job: #{e.message}")
        end

        job.fork

        fmt = requested_format
        if fmt == :json
          content_type 'application/json'
          {
            jobname: job.respond_to?(:name) ? job.name : job.to_s,
            path: job.respond_to?(:path) ? job.path : nil,
            status: (job.respond_to?(:status) ? job.status : 'created'),
            info: (job.respond_to?(:info) ? job.info : {})
          }.to_json
        else
        end
      end

      # GET /<workflow>/:task/:job - job status/info
      app.get "/#{name}/:task/:job" do
        task = consume_parameter(:task)
        job_id = consume_parameter(:job)
        unless workflow.tasks.include?(task.to_sym)
          return json_halt(404, message: "Task not found")
        end

        path = workflow.directory[task][job_id]

        if not path.exists?
          return json_halt(404, message: "Job not found")
        else
          job = Step.load path
        end

        fmt = requested_format
        case fmt
        when :json
          content_type 'application/json'
          if job.respond_to?(:info)
            job.info.to_json
          else
            { job: job_id, status: (job.respond_to?(:status) ? job.status : 'unknown') }.to_json
          end
        else
          render_template('job_result', workflow: workflow, task: task, result: job.load, job: job, jobname: job.name)
        end
      end

      # GET /<workflow>/:task/:job/files
      app.get "/#{name}/:task/:job/files" do
        task = consume_parameter(:task)
        job_id = consume_parameter(:job)
        unless workflow.tasks.include?(task.to_sym)
          return json_halt(404, message: "Task not found")
        end

        path = workflow.directory[task][job_id]

        if not path.exists?
          return json_halt(404, message: "Job not found")
        else
          job = Step.load path
        end

        fmt = requested_format
        case fmt
        when :json
          content_type 'application/json'
          files = job.respond_to?(:files) ? job.files : []
          files.to_json
        else
          status 406
          "HTML not implemented by REST component"
        end
      end

      # DELETE /<workflow>/:task/:job -> delete (clean) job
      app.delete "/#{name}/:task/:job" do
        task = consume_parameter(:task)
        job_id = consume_parameter(:job)
        unless workflow.tasks.include?(task.to_sym)
          return json_halt(404, message: "Task not found")
        end

        path = workflow.directory[task][job_id]

        if not path.exists?
          return json_halt(404, message: "Job not found")
        else
          job = Step.load path
        end

        # attempt to clean
        begin
          job.clean if job.respond_to?(:clean)
          status 200
          body({ok: true}.to_json)
        rescue => e
          json_halt(500, message: "Failed to clean job: #{e.message}")
        end
      end
    end
  end
end
