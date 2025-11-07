require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

module Pantry
  extend Resource
  self.subdir = 'share/pantry'
  Pantry.claim Pantry.eggs, :proc do
    Log.info "Buying Eggs in the store"
    "Eggs"
  end

  Pantry.claim Pantry.flour, :proc do
    Log.info "Buying Flour in the store"
    "Flour"
  end

  Pantry.claim Pantry.blueberries, :proc do
    Log.info "Buying Bluberries in the store"
    "Bluberries"
  end
end

module Baking
  extend Workflow

  self.description = <<-EOF
This is the Baking workflow
  EOF

  helper :whisk do |eggs|
    "Whisking eggs from #{eggs}"
  end

  helper :mix do |base, mixer|
    "Mixing base (#{base}) with mixer (#{mixer})"
  end

  helper :bake do |batter|
    "Baking batter (#{batter})"
  end

  task :whisk_eggs => :string do
    whisk(Pantry.eggs.produce)
  end

  dep :whisk_eggs
  input :add_bluberries, :boolean
  task :prepare_batter => :string do |add_bluberries|
    whisked_eggs = step(:whisk_eggs).load
    batter = mix(whisked_eggs, Pantry.flour.produce)

    if add_bluberries
      batter = mix(batter, Pantry.blueberries.produce) 
    end

    batter
  end

  dep :prepare_batter
  task :bake_muffin_tray => :string do 
    file('test').write "TEST FILE"
    bake(step(:prepare_batter).load)
  end


  export :bake_muffin_tray
end


require 'rack/test'
class TestSinatraWorkflows < Test::Unit::TestCase
  include Rack::Test::Methods

  class TestApp < Sinatra::Base
    register SinatraScoutBase
    register SinatraScoutWorkflow
    set :protection, false
  end

  setup do
    header 'Host', 'localhost'
    #Baking.directory = tmpdir.var.jobs.baking.find
    app.add_workflow Baking
    app.set :protection, false
    Pantry.path_maps[:test_tmp] = tmpdir.dup
    Pantry.path_maps[:default] = :test_tmp
    Pantry.map_order = [:test_tmp]
  end

  def app
    TestApp
  end

  def test_workflow_exports_json
    get '/Baking', { '_format' => 'json'}
    assert_equal 200, last_response.status, "expected 200 got #{last_response.status}: #{last_response.errors}"
    body = JSON.parse(last_response.body)
    assert body.key?('exec'), "expected 'exec' key in #{body.inspect}"
    assert body.key?('stream'), "expected 'stream' key in #{body.inspect}"
    assert body.key?('synchronous'), "expected 'synchronous' key in #{body.inspect}"
    assert body.key?('asynchronous'), "expected 'asynchronous' key in #{body.inspect}"
  end

  def _test_documentation_json
    get '/Baking/documentation', { '_format' => 'json' }
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_include body['description'], 'Baking'
  end

  def _test_task_info_json
    get '/Baking/bake_muffin_tray/info', { '_format' => 'json' }
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert body.key?('inputs'), "task_info should contain inputs: #{body.inspect}"
  end

  def _test_create_job_via_post
    post '/Baking/bake_muffin_tray', { 'add_bluberries' => true, '_format' => 'json' }
    assert_equal 200, last_response.status, "POST failed: #{last_response.body}"
    body = JSON.parse(last_response.body)
    assert body.key?('jobname'), "expected jobname in response: #{body.inspect}"
    assert body.key?('status'), "expected status in response: #{body.inspect}"
  end

  def _test_get_job_info
    post '/Baking/bake_muffin_tray', { 'add_bluberries' => true, '_format' => 'json' }
    assert_equal 200, last_response.status, "POST failed: #{last_response.body}"
    body = JSON.parse(last_response.body)
    get "/Baking/bake_muffin_tray/#{body['jobname']}", { '_format' => 'json' }
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert (body.is_a?(Hash) && (body.key?('status') || body.key?('job'))), "unexpected job info response: #{body.inspect}"
  end

  def _test_list_job_files
    post '/Baking/bake_muffin_tray', { 'add_bluberries' => true, '_format' => 'json' }
    assert_equal 200, last_response.status, "POST failed: #{last_response.body}"
    body = JSON.parse(last_response.body)
    get "/Baking/bake_muffin_tray/#{body['jobname']}/files", { '_format' => 'json' }
    body = JSON.parse(last_response.body)
    assert_kind_of Array, body
  end

  def _test_delete_job
    post '/Baking/bake_muffin_tray', { 'add_bluberries' => true, '_format' => 'json' }
    assert_equal 200, last_response.status, "POST failed: #{last_response.body}"
    body = JSON.parse(last_response.body)
    delete "/Baking/bake_muffin_tray/#{body['jobname']}"
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal true, body['ok']
    get "/Baking/bake_muffin_tray/#{body['jobname']}", { '_format' => 'json' }
    assert_equal 404, last_response.status
  end
end

