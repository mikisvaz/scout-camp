def lambda_handler(event:, context:)
  require 'scout'

  Path.path_maps[:bucket] = "s3://#{ENV["AWS_BUCKET"]}/{TOPLEVEL}/{SUBPATH}"
  Path.path_maps[:default] = :bucket

  require 'scout/workflow'
  require 'scout/aws/s3'

  TmpFile.tmpdir = Path.setup('/tmp')
  Open.sensible_write_dir = Path.setup('/tmp/sensible_write')

  Log.info "Payload: #{Log.fingerprint(event)}"

  workflow, task_name, jobname, inputs, clean, queue, info = IndiferentHash.process_options event,
    :workflow, :task_name, :jobname, :inputs, :clean, :queue, :info

  raise ParameterException, "No workflow specified" if workflow.nil?

  workflow = Workflow.require_workflow workflow

  case task_name
  when nil
    return {tasks: workflow.tasks.keys, documentation: workflow.documentation}
  when "info"
    raise ParameterException, "No task_name specified" if task_name.nil?
    return workflow.task_info(inputs["task_name"])
  else
    Workflow.job_cache.clear

    job = workflow.job(task_name, jobname, inputs)

    case clean
    when true, 'true'
      job.clean
    when 'recursive'
      job.recursive_clean
    end

    if info
      info = job.info.dup
      info["path"] = job.path
      info
    elsif job.done?
      job.load
    elsif job.error?
      raise job.exception
    elsif job.started?
      {
        statusCode: 202,
        body: job.path
      }
    elsif queue
      save_inputs = Scout.var.queue[workflow.to_s][task_name][job.name].find :bucket
      job.save_input_bundle(save_inputs) unless save_inputs.exists?
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
