require_relative 'base/helpers'
require_relative 'base/headers'
require_relative 'base/parameters'
require_relative 'base/assets'
require_relative 'base/session'
require_relative '../render/engine'

module SinatraScoutBase
  def self.registered(app)
    class << app
      def post_get(...)
        get(...)
        post(...)
      end
    end

    app.helpers ScoutRenderHelpers
    app.register SinatraScoutHelpers

    app.register SinatraScoutHeaders
    app.register SinatraScoutParameters
    app.register SinatraScoutPostProcessing
    app.register SinatraScoutAssets
    app.register SinatraScoutSession

    app.helpers do
      def json_halt(status, object = nil)
        status, object = 200, status if object.nil? 
        content_type 'application/json'
        halt status, (object.is_a?(String) ? {message: object}.to_json : object.to_json)
      end

      def html_halt(status, text = nil)
        status, text = 200, status if text.nil? 
        content_type 'text/html'
        halt status, text
      end

      def return_json(object)
        json_halt 200, object
      end

      def html(content, layout = false, extension: %w(slim haml erb))
        return content unless _layout 
        return content unless layout 
        layout = 'layout' if TrueClass === layout
        layout_file = ScoutRender.find_resource('layout', extension: extension )
        ScoutRender.render(layout_file, exec_context: self) do
          content
        end
      end

      def initiate_step(step, layout = nil, http_status = 200)
        step.clean if _update == :clean
        step.recursive_clean if _update == :recursive_clean
        step.clean if step.recoverable_error? && _update

        case _cache_type
        when :synchronous, :sync
          step.run
        when :asynchronous, :async
          step.fork unless step.started?
        when :exec
          halt http_status, html(step.exec, layout)
        end

        step.join if step.done?

        step
      end

      def serve_step(step, layout = nil, http_status = 200, &block)
        layout = _layout if layout.nil?
        case step.status
        when :error, 'error'
          Log.exception step.exception if Exception === step.exception
          raise step.exception
        when :done, 'done'
          step.join
          if block_given?
            block.call step
          else
            halt http_status || 200, html(step.load, layout)
          end
        else
          render_or('wait', "Waiting on #{step.path}", cache: false, step: step, http_status: 202)
        end
      end

      def serve_step_info(step)
        case step.status
        when 'done'
          json_halt 200, step.info
        when 'error'
          json_halt 500, step.info
        else
          json_halt 202, step.info
        end
      end

      def serve_step_json(step)
        case step.status
        when 'done'
          json_halt 200, step.load.to_json
        when 'error'
          json_halt 500, step.info
        else
          json_halt 202, step.info
        end
      end

      def serve_step_raw(step)
        case step.status
        when 'done'
          status 200
          mime_file step.path.find
        when 'error'
          json_halt 500, step.info
        else
          json_halt 202, step.info
        end
      end


      def render_template(template, options = {}, &block)
        layout, http_status = IndiferentHash.process_options options, :layout, :http_status,
          layout: _layout, http_status: 200
        options = IndiferentHash.setup(clean_params).merge(options) if defined?(clean_params)
        options = IndiferentHash.add_defaults options,
          update: _update,
          persist_step: _step,
          cache: _cache_type != :none

        step = ScoutRender.render_template(template, options.merge(exec_context: self, run: false), &block)
        if String === step
          status http_status
          return html step, layout
        end

        @step = step

        initiate_step step, layout, http_status

        post_processing @step

        serve_step step, layout, http_status
      end

      def render_partial(template, options = {}, &block)
        render_template(template, options.merge(layout: false, cache: false), &block)
      end

      def render_or(template, alt=nil, params = {}, &block)
        begin
          render_template(template, params)
        rescue TemplateNotFoundException
          if block_given?
            if block.arity == 0
              block.call
            else
              block.call params
            end
          else
            status = IndiferentHash.process_options params, :http_status, http_status: 200
            halt status, alt
          end
        end
      end
    end

    #{{{ HOOKS

    app.before do
      $script_name = script_name

      if request_method == 'POST' && request.content_type.include?('json')
        begin
          post_data = JSON.parse(request.body.read)
          params.merge!(post_data)
        rescue
          Log.exception $!
        end
      end

      method_color = case request_method
                     when "GET"
                       :cyan
                     when "POST"
                       :yellow
                     end

      Log.medium{ "#{Log.color method_color, request_method} #{Log.color(:blue, request.ip)}: " << path_info.gsub('/', Log.color(:blue, "/")) << ". Params: " << Log.color(:blue, Log.fingerprint(params))}

      process_common_parameters

      headers 'Access-Control-Allow-Origin' => '*'
    end

    app.after do
      if @step
        headers 'SCOUT_RENDER_STEP' => @step.name
      end

      if _update == :reload
        redirect to(fullpath)
      end
    end

    app.error  do
      error = env['sinatra.error']
      case _format
      when :json
        json_halt 500, {class: error.class.to_s, error: error.message, backtrace: error.backtrace}
      else
        render_or "error", error: error.message, backtrace: error.backtrace, http_status: 500 do
          <<-EOF
<pre>#{error.class}<pre/>
<pre>#{error.message}<pre/>
<pre>#{error.backtrace * "\n"}<pre/>
          EOF
        end
      end
    end

    #{{{ ROUTES

    app.post_get "/" do
      render_template('main', clean_params)
    end

    app.post_get "/main/*" do
      $title = "Scout"
      splat = consume_parameter :splat
      splat.unshift 'main'
      template = splat * "/"
      render_template(template, clean_params)
    end

  end
end
