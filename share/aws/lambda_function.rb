def lambda_handler(event:, context:)
  require 'scout'

  Path.path_maps[:bucket] = "s3://#{ENV["AWS_BUCKET"]}/{TOPLEVEL}/{SUBPATH}"
  Path.path_maps[:default] = :bucket

  require 'scout/workflow'
  require 'scout/aws/s3'

  workflow, task_name, jobname, inputs, clean, queue = IndiferentHash.process_options event,
    :workflow, :task_name, :jobname, :inputs, :clean, :queue

  raise ParameterException, "No workflow specified" if workflow.nil?

  workflow = Workflow.require_workflow workflow

  case task_name
  when nil
    return {tasks: workflow.tasks.keys, documentation: workflow.documentation}
  when "info"
    raise ParameterException, "No task_name specified" if task_name.nil?
    return workflow.task_info(inputs["task_name"])
  else
    job = workflow.job(task_name, jobname, inputs)

    case clean
    when true, 'true'
      job.clean
    when 'recursive'
      job.recursive_clean
    end

    if job.done?
      job.load
    elsif job.error?
      raise job.exception
    elsif job.started?
      {
        statusCode: 202,
        body: job.path
      }
    elsif queue
      save_inputs = Scout.var.queue[workflow.to_s][task_name][job.name].find
      job.save_inputs(save_inputs)
      {
        statusCode: 202,
        body: job.path
      }
    else
      job.produce
      job.load
    end
  end
end
