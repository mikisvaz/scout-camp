require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')


class TestRenderStep < Test::Unit::TestCase
  def test_render_proc
    out = ScoutRender.render(nil, name: 'Miguel') do |name|
      "Hi #{name}"
    end
    assert_equal 'Hi Miguel', out
  end

  def test_render_step
    step = ScoutRender.render_step(nil, name: 'Miguel') do |name|
      "Hi #{name}"
    end
    out = step.run
    assert_equal 'Hi Miguel', out
  end

  def test_render_step_template
    TmpFile.with_path do |dir|
      dir.share.views['test.haml'].write <<-'EOF'
%p Hi #{name}
      EOF
       
      ScoutRender.prepend_path :test_temp, dir 

      step = ScoutRender.render_step(dir.share.views['test.haml'], name: 'Miguel')
      step.clean
      out = step.run
      assert_include out, 'Hi Miguel'
      assert_include out, '<p>'
    end
  end

  def test_render_template
    TmpFile.with_path do |dir|
      dir.share.views['test.haml'].write <<-'EOF'
%p Hi #{name}
      EOF
       
      ScoutRender.prepend_path :test_temp, dir 

      out = ScoutRender.render_template('test', name: 'Miguel', layout: nil)
      assert_include out, 'Hi Miguel'
      assert_include out, '<p>'

      out = ScoutRender.render_partial('test', name: 'Miguel')
      assert_include out, 'Hi Miguel'
      assert_include out, '<p>'
    end
  end

  def test_render_template_no_run
    TmpFile.with_path do |dir|
      dir.share.views['test.haml'].write <<-'EOF'
%p Hi #{name}
      EOF
       
      ScoutRender.prepend_path :test_temp, dir 

      job = ScoutRender.render_template('test', name: 'Miguel', layout: nil, run: false)
      assert Step === job

      out = job.run

      assert_include out, 'Hi Miguel'
      assert_include out, '<p>'
    end
  end


  def test_render_template_no_cache
    TmpFile.with_path do |dir|
      dir.share.views['test.haml'].write <<-'EOF'
%p Hi #{name}
      EOF
       
      ScoutRender.prepend_path :test_temp, dir 

      out = ScoutRender.render_template('test', name: 'Miguel', layout: nil, cache: false)
      assert_include out, 'Hi Miguel'
      assert_include out, '<p>'
    end
  end
end

