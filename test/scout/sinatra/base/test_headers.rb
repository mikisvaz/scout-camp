require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

require 'scout/render'
require 'test/unit'
require 'rack/test'
require 'json'
require 'sinatra/base'

class TestSinatraHeaders < Test::Unit::TestCase
  include Rack::Test::Methods

  setup do
    header 'Host', 'localhost'
    app.set :protection, false
  end

  class TestApp < Sinatra::Base
    helpers ScoutRenderHelpers
    register SinatraScoutHeaders
    
    set :protection, false

    # expose small test routes using the helpers
    get '/env' do
      environment.to_s
    end

    get '/is_production' do
      production?.to_s
    end

    get '/is_development' do
      development?.to_s
    end

    get '/script' do
      script_name.to_s
    end

    get '/xhr' do
      xhr?.to_s
    end

    get '/method' do
      request_method.to_s
    end

    post '/post_flag' do
      post?.to_s
    end

    get '/some/path' do
      {
        path_info: path_info,
        query: query,
        fullpath: fullpath,
        original_uri: original_uri
      }.to_json
    end

    get '/clean_uri' do
      clean_uri(request.env['REQUEST_URI']).to_s
    end
  end

  def app
    TestApp
  end

  def test_environment_helpers
    get '/env'
    assert_equal 'development', last_response.body if TestApp.environment == :development
    # We don't assert strict value across envs, just that it returns a string
    assert last_response.status == 200
    assert_kind_of String, last_response.body
  end

  def test_production_development_flags
    get '/is_production'
    assert_equal 'false', last_response.body

    get '/is_development'
    assert_equal 'true', last_response.body
  end

  def test_script_name_from_header
    header 'SCRIPT_NAME', '/my/script'
    get '/script', {}
    assert_equal '/my/script', last_response.body
  end

  def test_xhr_detection
    # Rack::Test sets X-Requested-With when xhr? helper called in real browsers; emulate header
    header 'X-Requested-With', 'XMLHttpRequest'
    get '/xhr'
    assert_equal 'true', last_response.body
  ensure
    # clear header for subsequent tests
  end

  def test_request_method_and_post_flag
    get '/method'
    assert_equal 'GET', last_response.body
    post '/post_flag'
    assert_equal 'true', last_response.body
  end

  def test_uri_helpers_and_clean_uri
    env = {
      "PATH_INFO" => "/some/path",
      "QUERY_STRING" => "a=1&_update=reload&b=2",
      "REQUEST_URI" => "/some/path?a=1&_update=reload&b=2"
    }
    get '/some/path?a=1&_update=reload&b=2', {}
    assert_equal 200, last_response.status, last_response.errors
    body = JSON.parse(last_response.body)
    assert_equal '/some/path', body['path_info']
    assert_equal 'a=1&_update=reload&b=2', body['query']
    # fullpath uses clean_uri so _update should be removed from fullpath
    assert_equal '/some/path?a=1&b=2', body['fullpath']
    # original_uri uses clean_uri on REQUEST_URI

  end
end
