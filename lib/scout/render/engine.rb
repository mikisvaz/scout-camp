require_relative 'resource'
require_relative 'helpers'

require 'tilt'

class TemplateNotFoundException < StandardError; end
class FragmentNotFound < StandardError; end

module ScoutRender
  def self.render(template_file = nil, params = {}, &block)
    exec_context = IndiferentHash.process_options params, 
      :exec_context,
      exec_context: self

    if block && template_file.nil?
      params = params.values if Hash === params
      block.call *params
    else
      Log.debug "Render #{template_file}"
      begin
        Tilt.new(template_file).render(exec_context, params, &block)
      ensure
        exec_context.add_checks template_file if exec_context.respond_to? :add_checks
      end
    end
  end

  def self.render_step(template_file = nil, options = {}, &block)
    exec_context = IndiferentHash.process_options options, :exec_context

    persist_options = IndiferentHash.pull_keys options, :persist

    persist_options = IndiferentHash.add_defaults persist_options, 
      dir: ScoutRender.cache_dir, 
      other: options, 
      name: "Step"

    step_name = IndiferentHash.process_options persist_options, :step

    if step_name
      dir = persist_options[:dir]
      path = Path === dir ? dir[step_name] : File.join(dir, step_name)
      persist_options[:path] = path
    end
    
    path, extension, update = IndiferentHash.process_options persist_options, 
      :path, :extension, :update,
      path: Persist.persistence_path(persist_options[:name], persist_options),
      extension: 'html',
      update: update

    path = path.set_extension extension if extension and ! path.end_with?(".#{extension}")

    if block
      step = Step.new path, options, exec_context: exec_context, &block
    else
      step = Step.new path, options, exec_context: exec_context do
        ScoutRender.render(template_file, options.merge(exec_context: self))
      end
    end

    step.exec_context = step unless exec_context
    
    step.type = :text

    step.extend ScoutRenderHelpers if exec_context.nil?

    step.exec_context.instance_variable_set(:@step, step)

    step
  end

  def self.render_template(template = nil, options = {}, &block)
    options = IndiferentHash.add_defaults options, persist_name: template

    extension, update, run, cache, check = IndiferentHash.process_options options, 
      :extension, :update, :run, :cache, :check,
      extension: %w(slim haml erb),
      run: true,
      cache: true

    template_file = ScoutRender.find_resource(template, extension: extension) if template

    raise TemplateNotFoundException, template unless template_file.nil? || template_file.exists?

    return ScoutRender.render(template_file, options, &block) if ! cache

    step = ScoutRender.render_step(template_file, options, &block)

    #checks = step.info[:checks] || []
    #checks << check if check
    #checks << [template_file]
    #checks = checks.flatten.uniq
    #step.set_info :checks, checks

    case update
    when :false, 'false', false, :wait, 'wait'
    when :true, 'true', true, :reload, 'reload'
      step.clean
    when nil
      if checks = step.info[:checks]
        step.clean if (step.done? || step.error?) && step.path.outdated?(checks)
      end
    else
      step.clean if step.error? && step.recoverable_error?
      step.clean unless step.running?
    end

    if run
      step.run
    else
      step
    end
  end

  def self.render_partial(template, options = {})
    render_template(template, options)
  end
end
