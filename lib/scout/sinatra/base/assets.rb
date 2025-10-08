module SinatraScoutAssets
  def self.registered(app)
    app.helpers do
      def reset_js_css
        @recorded_js_files = []
        @recorded_css_files = []
      end

      def recorded_js_files_global
        @recorded_js_files ||= []
      end

      def recorded_css_files_global
        @recorded_css_files ||= []
      end

      def recorded_js_files
        global = recorded_js_files_global
        return global unless @step
        global + (@step.info[:js_files] || [])
      end

      def recorded_css_files
        global = recorded_css_files_global
        return global unless @step
        global + (@step.info[:css_files] || [])
      end

      def record_js_global(file)
        if Array === file
          recorded_js_files.concat file
        else
          recorded_js_files << file
        end
      end

      def record_css_global(file)
        if Array === file
          recorded_css_files.concat file
        else
          recorded_css_files << file
        end
      end

      def record_js(js_files)
        return record_js_global(js_files) unless @step
        js_files = [js_files] unless Array === js_files
        @step.load_info
        current_js_files = @step.info[:js_files] || []

        @step.set_info :js_files, js_files - current_js_files
      end

      def record_css(css_files)
        return record_css_global(css_files) unless @step
        css_files = [css_files] unless Array === css_files
        @step.load_info
        current_css_files = @step.info[:css_files] || []

        new_files = css_files - current_css_files
        @step.set_info :css_files, new_files
      end

      def link_css(file)
        file << "?_update=reload" if @debug_css
        html_tag('link', nil, :rel => 'stylesheet', :type => 'text/css', :href => file)
      end

      def link_js(file)
        html_tag('script', " ", :src => file, :type => 'text/javascript')
      end

      def serve_css
        md5 = Misc.digest(recorded_css_files * ",")
        filename = ScoutRender.cache_dir["all_css-#{md5}.css"].find

        paths = recorded_css_files.collect do |file|
          if Open.remote?(file)
            path = file
          else
            path = ScoutRender.find_js(file)
            path = ScoutRender.find_js("public/#{file}") unless path.exists?
          end
          path
        end

        update = _update == :css
        checks = paths.select{|p| Open.mtime(p) }

        Persist.persist 'all', :text, prefix: 'css', path: filename, other: {files: paths}, check: checks, update: update do
          Log.debug{ "Regenerating CSS Compressed file: #{ filename }" }
          paths.collect do |path|
            TmpFile.with_file do |tmpfile|
              cmd_str = "-i '#{path}' -o '#{tmpfile}'"
              CMD.cmd(:tailwindcss, cmd_str)
              Open.read tmpfile
            end
          end * "\n"
        end

        res = "<link href='/file/#{File.basename(filename)}' rel='stylesheet' type='text/css'/>"

        recorded_css_files.clear

        res
      end

      def serve_js
        md5 = Misc.digest(recorded_js_files * ",")
        filename = ScoutRender.cache_dir["all_js-#{md5}.js"].find

        paths = recorded_js_files.collect do |file|
          if Open.remote?(file)
            path = file
          else
            path = ScoutRender.find_js(file)
            path = ScoutRender.find_js("public/#{file}") unless path.exists?
          end
          path
        end

        update = _update == :js

        minify = false
        checks = paths.select{|p| Open.mtime(p) }

        Persist.persist 'all', :text, prefix: 'js', path: filename, other: {files: paths}, check: checks, update: update do
          Log.debug{ "Regenerating JS Compressed file: #{ filename }" }
          TmpFile.with_file nil, false do |tmp_file|
            Open.write tmp_file do |f|
              paths.each do |path|
                f.write(Open.read(path) + "\n")
              end
            end

            cmd_str = "esbuild ".dup
            cmd_str << "'#{tmp_file}' "
            cmd_str << "--outfile='#{filename}' "
            cmd_str << "--bundle "
            cmd_str << "--minify " if minify
            cmd_str << "--platform='browser' "
            CMD.cmd(:npx, cmd_str)
          end
        end

        res = "<script src='/file/#{File.basename(filename)}' type='text/javascript' defer></script>"

        recorded_js_files.clear

        res
      end

      def mime_file(file, content_type = nil)
        if file.end_with?('.js')
          content_type = 'text/javascript'
        elsif file.end_with?('.css')
          content_type = 'text/css'
        else
          content_type = 'text/html'
        end if content_type.nil?

        Log.debug "Serving #{file} as #{content_type}"
        content_type content_type if content_type
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
      status 200
      mime_file file
    end

    app.get '/(stylesheets|css)/*' do
      splat = consume_parameter(:splat)

      splat.unshift 'public/css'

      name = splat * "/"

      file = ScoutRender.find_resource(name)

      if file.exists?
        content_type 'text/css', :charset => 'utf-8'
        cache_control :public, :max_age => 360000 if production?

        mime_file file, false
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
      status 200
      mime_file file, false
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
