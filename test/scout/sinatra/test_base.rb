require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

require 'rack/test'
class TestSinatraBase < Test::Unit::TestCase
  include Rack::Test::Methods

  class TestApp < Sinatra::Base
    set :protection, false
    register SinatraScoutBase
    set :protection, false
  end

  setup do
    header 'Host', 'localhost'
    app.set :protection, false
  end

  def app
    TestApp
  end

  def test_true

  end
end

