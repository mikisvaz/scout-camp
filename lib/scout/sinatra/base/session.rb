require "sinatra"

module SinatraScoutSession
  def self.registered(app)
    app.configure do
      app.set :sessions, true
    end

    secret = Scout::Config.get :secret, :sinatra_session, :sinatra, :session, env:"SESSION_SECRET", default: "scout_and_rbbt_super_secret"
    app.use Rack::Session::Cookie, secret: secret

    app.get '/debug_session' do
        "Session contents: #{session.inspect}"
    end
  end
end
