require 'test/unit'
require 'tempfile'
require 'scout/log'
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
$LOAD_PATH.unshift(__dir__)

class Test::Unit::TestCase

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
