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
          puts "OmniAuth session: #{env['rack.session'].inspect}"
        }
    end

    app.get "/auth/login" do
      session[:return_to] = request.referer || "/"

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
    end
  end
end
