require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

require 'rack/test'

module TestEntity
  extend Entity

  property :hi do |name=nil|
    "Hi #{name||self}"
  end
end

class TestSinatraWorkflows < Test::Unit::TestCase
  include Rack::Test::Methods

  class TestApp < Sinatra::Base
    set :protection, false
    register SinatraScoutBase
    register SinatraScoutEntity
    set :protection, false
  end

  setup do
    header 'Host', 'localhost'
  end

  def app
    TestApp
  end

  def test_property
    get '/entity_property/TestEntity/hi/Test', { '_format' => 'json'}
    assert_equal 200, last_response.status, "expected 200 got #{last_response.status}: #{last_response.errors}"
    body = IndiferentHash.setup(JSON.parse(last_response.body))
    assert_equal "Hi Test", body[:message]

    get '/entity_property/TestEntity/hi/Test', { '_format' => 'json', args: "Miguel"}
    assert_equal 200, last_response.status, "expected 200 got #{last_response.status}: #{last_response.errors}"
    body = IndiferentHash.setup(JSON.parse(last_response.body))
    assert_equal "Hi Miguel", body[:message]
  end
end

