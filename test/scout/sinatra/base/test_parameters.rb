require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

require 'scout/render'
require 'test/unit'
require 'rack/test'
require 'json'
require 'sinatra/base'
require 'scout/sinatra/base/headers'

class TestSinatraHeaders < Test::Unit::TestCase
  include Rack::Test::Methods

  setup do
    header 'Host', 'localhost'
    app.set :protection, false
  end

  # register a temporary common parameter for testing
  SinatraScoutParameters.register_common_parameter(:_flag_test, :boolean, nil) { false }

  class TestApp < Sinatra::Base
    register SinatraScoutHeaders
    register SinatraScoutParameters

    # route to inspect consume_parameter
    get '/consume' do
      val = consume_parameter('x', params)
      (val.nil? ? 'nil' : val.to_s)
    end

    get '/clean' do
      content_type 'application/json'
      clean_params.to_json
    end

    get '/process_common' do
      # call process_common_parameters and return the value of the helper-generated method
      process_common_parameters
      _flag_test.to_s
    end
  end

  def app
    TestApp
  end

  def test_consume_parameter_blank_becomes_nil
    get '/consume', { 'x' => '' }
    assert_equal 'nil', last_response.body
  end

  def test_clean_params_removes_internal_keys_and_checkbox_false
    params = {
      'name' => 'John',
      '_internal' => 'should_remove',
      'agree_checkbox_false' => '1'
    }
    get '/clean', params
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    # _internal should not be present
    assert !body.key?('_internal')
    # agree_checkbox_false should be removed; agree should be false (since no 'agree' key present)
    assert_equal false, body['agree']
    assert_equal 'John', body['name']
  end

  def test_common_parameter_helper_created_and_defaults_work
    # no param provided, the registered default block returns false
    get '/process_common'
    assert_equal 'false', last_response.body
  end

  def test_consume_parameter_from_given_source_hash
    # supply nested hash as source
    source = { 'a' => '1', 'b' => '' }
    # create a route to call consume_parameter with a custom source
    TestApp.get '/consume_custom' do
      v1 = consume_parameter('a', source)
      v2 = consume_parameter('b', source)
      "#{v1}-#{v2.inspect}"
    end

    get '/consume_custom'
    assert_equal '1-nil', last_response.body
  end
end
