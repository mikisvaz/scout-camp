require 'test/unit'
require 'tempfile'
require 'scout/log'
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
$LOAD_PATH.unshift(__dir__)

require 'scout'
class Test::Unit::TestCase

  def self.tmpdir
    @@tmpdir ||= Path.setup('tmp/test_tmpdir').find
  end

  def tmpdir
    @tmpdir ||= Test::Unit::TestCase.tmpdir
  end

  setup do
    Open.rm_rf tmpdir
    TmpFile.tmpdir = tmpdir.tmpfiles
    Log::ProgressBar.default_severity = 0
    Persist.cache_dir = tmpdir.var.cache
    Persist::MEMORY_CACHE.clear
    Open.remote_cache_dir = tmpdir.var.cache
    Workflow.directory = tmpdir.var.jobs
    Workflow.workflows.each{|wf| wf.directory = Workflow.directory[wf.name] }
    Entity.entity_property_cache = tmpdir.entity_properties if defined?(Entity)
    ScoutRender.app_dir = tmpdir.var.render
  end

  teardown do
    Open.rm_rf tmpdir
    Workflow.job_cache.clear
  end
  def with_tmp_file
    name = 'test_file_terraform_' + rand(100000).to_s
    file = File.join('/tmp', name)
    begin
      yield file
    ensure
      FileUtils.rm_rf file
    end
  end

end
