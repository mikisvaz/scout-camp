module SinatraScoutAssets
  def self.registered(app)
    app.helpers do
      def recorded_js_files
        @recorded_js_files ||= []
      end

      def recorded_css_files
        @recorded_css_files ||= []
      end

      def reset_js_css
        @recorded_js_files = []
        @recorded_css_files = []
      end


      def record_js(file)
        recorded_js_files << file
      end

      def record_css(file)
        recorded_css_files << file
      end

      def link_css(file)
        #file += '.css' unless file =~ /.css$/
        file << "?_update=reload" if @debug_css
        html_tag('link', nil, :rel => 'stylesheet', :type => 'text/css', :href => file)
      end

      def link_js(file)
        #file += '.js' unless file =~ /.js$/
        html_tag('script', " ", :src => file, :type => 'text/javascript')
      end

      def serve_js(compress = true)
        if production? and compress and not @debug_js 
          md5 = Misc.digest(recorded_js_files * ",")
          filename = ScoutRender.cache_dir["all_js-#{md5}.js"].find

          if not File.exist?(filename)
            require 'uglifier'
            Log.debug{ "Regenerating JS Compressed file: #{ filename }" }

            text = recorded_js_files.collect{|file| 
              if Open.remote?(file)
                path = file
              else
                path = ScoutRender.find_js(file)
                path = ScoutRender.find_js("public/#{file}") unless path.exists?
              end

              "//FILE: #{ File.basename(path) }\n" +  Open.read(path)
            } * "\n"

            FileUtils.mkdir_p File.dirname(filename) unless File.exist? File.dirname(filename)
            #Open.write(filename, Uglifier.compile(text, :harmony => true))
            Open.write(filename, text)
          end

          res = "<script src='/file/#{File.basename(filename)}' type='text/javascript' defer></script>"
        else
          res = recorded_js_files.collect{|file|
            link_js(file)
          } * "\n"
        end

        recorded_js_files.clear

        res
      end

      def serve_css
        res = recorded_css_files.collect{|file|
          link_css(file)
        } * "\n"

        recorded_css_files.clear

        res
      end

      def mime_file(file)
        if file.end_with?('.js')
          content_type = 'text/javascript'
        elsif file.end_with?('.css')
          content_type = 'text/css'
        else
          content_type = 'text/html'
        end
        Log.debug "Serving #{file} as #{content_type}"
        content_type content_type
        send_file(file)
      end
    end

    # helpers for REST-style responses & params
    # expose method to register a workflow at runtime
    app.get "/plugins/*" do
      splat = consume_parameter(:splat)

      splat.unshift 'public/plugins'

      name = splat * "/"

      file = ScoutRender.find_resource(name)
      mime_file file
    end

    app.get '/stylesheets/*' do
      splat = consume_parameter(:splat)

      splat.unshift 'public/css'

      name = splat * "/"

      file = ScoutRender.find_resource(name)

      if file.exists?
        content_type 'text/css', :charset => 'utf-8'
        cache_control :public, :max_age => 360000 if production?

        mime_file file
      else
        splat.shift

        splat.unshift 'compass'

        name = splat * "/"

        content_type 'text/css', :charset => 'utf-8'
        cache_control :public, :max_age => 360000 if production?

        render_template(name.sub(/\.css/, '.sass'))
      end
    end

    app.get '/js/*' do
      splat = consume_parameter(:splat)

      splat.unshift 'public/js'

      name = splat * "/"

      file = ScoutRender.find_resource(name)
      content_type 'application/javascript'
      mime_file file
    end

    app.get '/file/*' do
      splat = consume_parameter(:splat)

      name = splat * "/"
      if ScoutRender.cache_dir[name].exists?
        mime_file ScoutRender.cache_dir[name].find
      end

      splat.unshift 'public'
      name = splat * "/"
      file = ScoutRender.find_resource(name)
      mime_file file
    end
  end
end
