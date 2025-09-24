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
      Tilt.new(template_file, :filename => template_file).render(exec_context, params, &block)
    end
  end

  def self.render_step(template_file = nil, options = {}, &block)
    exec_context = IndiferentHash.process_options options, :exec_context

    persist_options = IndiferentHash.pull_keys options, :persist

    persist_options = IndiferentHash.add_defaults persist_options, 
      dir: ScoutRender.cache_dir, 
      other: options, 
      name: "Step"

    path, extension, update, check = IndiferentHash.process_options persist_options, 
      :path, :extension, :update, :check,
      path: Persist.persistence_path(persist_options[:name], persist_options),
      extension: 'html',
      update: update

    path = path.set_extension extension if extension

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

    extension, update, run, cache = IndiferentHash.process_options options, 
      :extension, :update, :run, :cache,
      extension: %w(slim haml erb),
      run: true,
      cache: true

    template_file = ScoutRender.find_resource(template, extension: extension) if template

    raise TemplateNotFoundException, template unless template_file.nil? || template_file.exists?

    return ScoutRender.render(template_file, options, &block) if ! cache

    @step = step = ScoutRender.render_step(template_file, options, &block)

    step.exec_context.add_checks [template_file] 

    case update
    when 'false', false, :wait, 'wait'
    when 'true', true
      step.clean
    when nil
      step.clean if step.exec_context.outdated?
    else
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
