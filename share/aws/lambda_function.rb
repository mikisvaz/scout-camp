def lambda_handler(event:, context:)
  require 'scout'

  Path.path_maps[:bucket] = "s3://#{ENV["AWS_BUCKET"]}/{TOPLEVEL}/{SUBPATH}"
  Path.path_maps[:default] = :bucket

  TmpFile.tmpdir = Path.setup('/tmp')
  Open.sensible_write_dir = Path.setup('/tmp/sensible_write')

  require 'scout/workflow'
  require 'scout/aws/s3'


  Log.info "Payload: #{Log.fingerprint(event)}"

  workflow, task_name, jobname, inputs, clean, queue, info, path = IndiferentHash.process_options event,
    :workflow, :task_name, :jobname, :inputs, :clean, :queue, :info, :path

  task_name = "path" if path
  raise ParameterException, "No workflow specified" if workflow.nil?

  case task_name
  when nil
    return {tasks: workflow.tasks.keys, documentation: workflow.documentation}
  when "info"
    raise ParameterException, "No task_name specified" if task_name.nil?
    return workflow.task_info(inputs["task_name"])
  else
    Workflow.job_cache.clear

    if path
      job = Step.load path
      task_name = job.task_name
      workflow = job.workflow
      wait = true
    else
      workflow = Workflow.require_workflow workflow
      job = workflow.job(task_name, jobname, inputs)
    end

    Log.info "Job info: #{job.info}"

    case clean
    when true, 'true'
      job.clean
    when 'recursive'
      job.recursive_clean
    end

    begin
      if info
        info = job.info.dup
        info["path"] = job.path
        {info: info}
      elsif job.done?
        job.load_info unless job.status == :done
        {result: job.load}
      elsif job.error?
        {exception: job.exception, error: job.exception.message}
      elsif job.started?
        {job: job.path, info: job.info, status: job.info[:status] }
      elsif queue
        save_inputs = Scout.var.queue[workflow.to_s][task_name][job.name].find :bucket

        job.save_info status: :queue 
        job.save_input_bundle(save_inputs) unless save_inputs.exists?

        Log.info "Queue: #{save_inputs}"

        {job: job.path}
      elsif wait
        save_inputs = Scout.var.queue[workflow.to_s][task_name][job.name].find :bucket
        if not save_inputs.exists?
          job.join
          raise TryAgain 
        else
          {job: job.path}
        end
      else
        job.produce
        raise TryAgain
      end
    rescue TryAgain
      retry
    end
  end
end
