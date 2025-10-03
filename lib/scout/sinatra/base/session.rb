require "sinatra"

module SinatraScoutSession
  def self.registered(app)
    secret = Scout::Config.get :secret, :sinatra_session, :sinatra, :session, env:"SESSION_SECRET", default: "scout_and_rbbt_super_secret"

    app.configure do
      app.enable :sessions
      app.set :sessions, true
      app.set :session_secret, secret
    end

    app.use Rack::Session::Cookie, secret: secret

    app.get '/debug_session' do
      "Session contents: #{session.inspect}"
    end

    app.post_get '/preference/:key' do
      key = consume_parameter :key
      value = consume_parameter :value

      if value.nil?
        consume_parameter :key
        case _format
        when :json
          content_type 'application/json'
          get_preference(key).to_json
        else
          get_preference(key)
        end
      else

        case _format
        when :json
          value = JSON.parse(value)
        else
          record_preference(key, value)
        end
        halt 200
      end
    end

    app.helpers do
      def preferences
        session['preferences'] ||= {}
      end

      def record_preference(key, value)
        preferences[key] = value
      end

      def get_preference(key)
        preferences[key]
      end

      def preference_url(key, value=nil, params = {})
        url = "/preference/#{key}"
        if value
          add_GET_params("/preference/#{key}", params.merge(value: value))
        else
          add_GET_params("/preference/#{key}", params)
        end
      end
    end
  end
end
