require_relative 'base/helpers'
require_relative 'base/headers'
require_relative 'base/parameters'
require_relative 'base/assets'
require_relative 'base/session'
require_relative '../render/engine'

module SinatraScoutBase
  def self.registered(app)
    app.helpers ScoutRenderHelpers
    app.register SinatraScoutHelpers

    app.register SinatraScoutHeaders
    app.register SinatraScoutParameters
    app.register SinatraScoutAssets
    app.register SinatraScoutSession

    app.helpers do
      def html(content, layout = false, extension: %w(slim haml erb))
        return content unless _layout 
        return content unless layout 
        layout = 'layout' if TrueClass === layout
        layout_file = ScoutRender.find_resource('layout', extension: extension )
        ScoutRender.render(layout_file, exec_context: self) do
          content
        end
      end

      def render_template(template, options = {}, &block)
        layout = IndiferentHash.process_options options, :layout, layout: _layout
        options = IndiferentHash.setup(clean_params).merge(options) if defined?(clean_params)
        options = IndiferentHash.add_defaults options, 
          update: _update, 
          cache: _cache_type != :none

        step = ScoutRender.render_template(template, options.merge(exec_context: self, run: false), &block)
        return html step, layout if String === step

        @step = step

        case _cache_type
        when :synchronous
          step.run
        when :asynchronous
          step.fork unless step.started?
        when :exec
          halt 200, html(@step.exec, layout)
        end

        post_processing @step

        case @step.status
        when :error, 'error'
          render_template('error', cache: false, step: @step)
        when :done, 'done'
          @step.join
          halt 200, html(@step.load, layout)
        else
          halt 200, render_template('wait', cache: false, step: @step)
        end
      end

      def render_partial(template, options = {}, &block)
        render_template(template, options.merge(layout: false, cache: false), &block)
      end

      alias partial_render render_partial

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
            halt 200, alt
          end
        end
      end
    end

    app.before do
      $script_name = script_name

      if request_method == 'POST' && request.content_type.include?('json')
        begin
          post_data = JSON.parse(request.body.read)
          params.merge!(post_data)
        rescue
          Log.exception $!
        ensure
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

    app.get "/" do
      render_template('main', clean_params)
    end

    app.get "/main/*" do
      $title = "Scout"
      splat = consume_parameter :splat
      splat.unshift 'main'
      template = splat * "/"
      render_template(template, clean_params)
    end

    app.after do
      if _update == :reload
        redirect to(uri)
      end
    end
  end
end

SinatraScoutParameters.register_common_parameter(:_layout, :boolean) do ! ajax?  end
SinatraScoutParameters.register_common_parameter(:_format, :symbol) do :html end
SinatraScoutParameters.register_common_parameter(:_update, :symbol) do development? ? :development : nil  end
SinatraScoutParameters.register_common_parameter(:_cache_type, :symbol, :asynchronous)
SinatraScoutParameters.register_common_parameter(:_debug_js, :boolean)
SinatraScoutParameters.register_common_parameter(:_debug_css, :boolean)
