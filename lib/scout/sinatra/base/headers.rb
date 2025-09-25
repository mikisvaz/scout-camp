module SinatraScoutHeaders
  def self.registered(app)
    app.helpers do
      def environment
        settings.environment 
      end

      def production?
        environment == :production
      end

      def development?
        environment == :development
      end

      def script_name
        request.script_name ||= request.env["HTTP_SCRIPT_NAME"]
      end

      def xhr?
        request.xhr?
      end

      def ajax?
        request.xhr?
      end

      def request_method
        request.env["REQUEST_METHOD"]
      end

      def post?
        request_method.to_s.downcase == 'post'
      end

      def clean_uri(uri)
        return nil if uri.nil?
        remove_GET_param(uri, ["_update", "_", "_layout"])
      end

      def original_uri
        clean_uri(request.env["REQUEST_URI"])
      end

      def post_uri
        new_params = {}
        params.each do |k,v|
          if m = k.match(/(.*)__param_file/)
            new_params[m[1]] = v['filename']
          else
            new_params[k] = v
          end
        end
        hash = Misc.digest(new_params)
        params[:_layout]
      end

      def path_info
        @path_info ||= request.env["PATH_INFO"]
      end

      def query
        @query ||= request.env["QUERY_STRING"]
      end

      def fullpath
        @fullpath ||= (query && ! query.empty?) ? clean_uri(path_info + "?" + query) : path_info
      end

      alias url fullpath

      def script_name
        @script_name ||= request.script_name = request.env["HTTP_SCRIPT_NAME"]
      end
    end
  end
end
