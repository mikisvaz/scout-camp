require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

class TestScoutRenderResource < Test::Unit::TestCase
  def test_find_template_registered_dir
    TmpFile.with_path do |dir|
      dir.share.views['test_find_template.haml'].write "Test"

      path = ScoutRender.find_haml('test_find_template')
      refute path.exists?

      path = ScoutRender.find_resource('test_find_template', extension: 'haml')
      refute path.exists?

      path = ScoutRender.find_resource('test_find_template', extension: ['haml'])
      refute path.exists?

      ScoutRender.prepend_path :tmp_dir, dir

      path = ScoutRender.find_haml('test_find_template')
      assert path.exists?

      ScoutRender.path_maps.delete :tmp_dir

      path = ScoutRender.find_haml('test_find_template')
      refute path.exists?
    end
  end
end
