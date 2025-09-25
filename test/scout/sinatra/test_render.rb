require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

require 'rack/test'

class TestSinatraRender < Test::Unit::TestCase
  include Rack::Test::Methods

  class TestApp < Sinatra::Base
    set :protection, false
    register SinatraScoutRender
    set :protection, false
  end

  def app
    TestApp
  end

  setup do
    header 'Host', 'localhost'
    app.set :protection, false
  end


  def test_get
    TmpFile.with_path do |dir|
      dir.share.views.main['test.haml'].write <<-'EOF'
%p Hi #{name}
      EOF

      dir.share.views['layout.haml'].write <<-'EOF'
%H3 Layout
!= yield
      EOF
       
      ScoutRender.prepend_path :test_temp, dir 

      get '/main/test', { '_format' => 'json', 'name' => "Miguel"}
      assert_equal 200, last_response.status, "expected 200 got #{last_response.status}: #{last_response.status == 500 ? last_response.errors : last_response.body}"
      assert_include = last_response.body, 'Miguel'
    end
  end
end

