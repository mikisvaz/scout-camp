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
          job = template
          task_name = job.task_name
          render_template("#{workflow}/#{task_name}", params.merge(task: task_name, job: job))
        end
      end

      def workflow_template(workflow, task, type = :job)
        workflow_name = Workflow === workflow ? workflow.name : workflow.to_s
        file = File.join(workflow_name, task, type.to_s)
        return file if ScoutRender.exists?(file)

        file = File.join(workflow_name, type.to_s)
        return file if ScoutRender.exists?(file)

        file = File.join(type.to_s)
        return file if ScoutRender.exists?(file)

        raise TemplateNotFoundException, "Workflow template not fond for workflow #{workflow_name} task #{task} type #{type}"
      end

      def render_job(workflow, job, params = {})
        task = job.task_name
        template = workflow_template(workflow, task)
        render_template(template, params.merge(job: job, task: task, workflow: workflow))
      end

      def job_url(job)
        workflow = job.workflow
        task = job.task_name
        name = job.name
        workflow_name = Workflow === workflow ? workflow.name : workflow.to_s

        '/' + [workflow_name, task, name] * "/"
      end

      def workflow_name
        return nil unless task_name
        return fullpath.split("/")[1]
      end

      def workflow
        return nil unless workflow_name
        Kernel.const_get workflow_name
      end

      def job_name
        splat * "/"
      end

      def job
        return nil unless task_name
        return nil unless job_name
        job = workflow.load_job task_name, job_name
      end
    end

    # expose method to register a workflow at runtime
    app.define_singleton_method(:add_workflow) do |workflow, opts = {}|
      name = workflow.to_s.split('::').last
      settings.registered_workflows[name] = workflow
      settings.knowledge_base = workflow.knowledge_base if workflow.knowledge_base
      ScoutRender.prepend_path name, workflow.libdir

      # GET /<workflow> - exports
      app.get "/#{name}/:task_name/*" do
        job = workflow.load_job task_name, job_name

        case _format
        when :info
          serve_step_info job
        when :json
          serve_step_json job
        when :raw
          serve_step_raw job
        else
          serve_step job, _layout, params do
            begin
              render_job workflow, job, params
            rescue TemplateNotFoundException
              halt 200, "Job #{job.short_path} done"
            end
          end
        end
      end
    end

    app.register_common_parameter(:task_name, :symbol)
  end
end

