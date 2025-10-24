require "sinatra"
require "omniauth"
require "omniauth-google-oauth2"

module SinatraScoutAuth
  def self.registered(app)

    app.use OmniAuth::Builder do
      client_id = Scout::Config.get :client, :google, :google_oauth, env:"GOOGLE_CLIENT_ID"
      client_secret = Scout::Config.get :secret, :google, :google_oauth, env:"GOOGLE_CLIENT_SECRET"
      provider :google_oauth2, client_id, client_secret,
        access_type: 'offline',
        prompt: 'select_account',
        scope: 'email',
        setup: lambda { |env|
          script_name = env['HTTP_SCRIPT_NAME']
          if script_name
            referer = env['rack.session']['return_to']
			uri = URI.parse(referer)
			# Keep only scheme + host + (optional port)
			base = "#{uri.scheme}://#{uri.host}"
			base += ":#{uri.port}" if uri.port && ![80, 443].include?(uri.port)

			# Construct full redirect URI
			redirect_uri = "#{base}#{script_name}/auth/google_oauth2/callback"

            strategy = env['omniauth.strategy']

            strategy.options[:redirect_uri] = redirect_uri
          end

          puts "OmniAuth session: #{env['rack.session'].inspect}"
        }
    end

    app.get "/auth/login" do
      session[:return_to] = to(request.referer || "/")

      render_or 'auth/login', <<~HTML
          <form method='get' action='/auth/google_oauth2'>
          <input type="hidden" name="authenticity_token" value='#{request.env["rack.session"]["csrf"]}'>
          <button type='submit'>Login with Google</button>
          </form>
      HTML
    end

    app.get "/auth/:provider/callback" do
      auth = request.env["omniauth.auth"]

      # Store relevant info in session
      session[:user] = {
        uid: auth.uid,
        name: auth.info.name,
        email: auth.info.email,
        image: auth.info.image
      }

      return_to = session[:return_to]
      redirect return_to || "/"
    end

    app.get "/auth/logout" do
      return_to = session[:return_to]
      session.clear
      render_or 'auth/logout', nil, return_to: return_to do
        redirect return_to || "/"
      end
    end

    app.get "/auth/failure" do
      render_or 'auth/fail', "Authentication failed: #{params[:message]}"
    end

    app.helpers do
      def current_user
        session[:user]
      end

      def authenticated?
        !current_user.nil?
      end

      def protected!
        render_or 'auth/missing', "Not authorized" unless authenticated?
      end

      def user_name
        case current_user
        when Hash
          current_user[:name] || current_user['name'] || current_user[:email] || current_user['email']
        when String
          current_user
        end
      end

      def user_dir
        Scout.var.sinatra.users[user_name]
      end

      def user_file(file)
        user_dir[file.to_s]
      end

      def user_save(file, content)
        Open.sensible_write(user_file(file), content, force: true)
      end

      def user_load(file)
        return nil unless user_file(file).exists?
        user_file(file).read
      end

      def save_preferences
        Log.debug "save #{preferences.to_json}"
        user_save(:preferences, preferences.to_json)
      end

      def load_preferences
        return unless user_file(:preferences).exists?
        session['preferences'] = JSON.parse(user_load(:preferences))
        session['preferences_time'] = user_file(:preferences).mtime
      end

      def updated_preferrences?
        return true if session['preferences_time'].nil?
        session['preferences_time'] < user_file(:preferences).mtime
      end

      def preferences_changed
        @preferences_changed ||= []
      end

      def record_preference(key, value)
        preferences_changed << key
        preferences[key] = value
        save_preferences if current_user
        value
      end

      def get_preference(key)
        load_preferences if current_user && updated_preferrences?
        preferences[key]
      end

      def preference(key, default= nil, &block)
        current = get_preference(key)
        return current unless current.nil?
        default = block.call if default.nil? and block_given?
        record_preference(key, default) if default
        default
      end
    end
  end
end
