require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

require 'scout/workflow'
class TestS3 < Test::Unit::TestCase
  def test_list
    file = "s3://herlab/tmp/foo.txt"

    Open::S3.write file, "TEST"

    dir = "s3://herlab/tmp"

    assert_include Open::S3.glob(dir, "**/*"), file
  end

  def test_write
    uri = "s3://herlab/tmp/foo.txt"

    Open.write uri, "TEST"
    assert_equal "TEST", Open.read(uri)
    Open.rm uri
  end

  def test_touch_size
    uri = "s3://herlab/tmp/foo.txt"

    Open.rm uri
    Open.touch uri
    assert_equal 0, Open.size(uri)
    Open.rm uri
  end

  def test_write_io
    uri = "s3://herlab/tmp/foo.txt"

    Open::S3.write uri, "TEST"
    io = Open::S3.get_stream uri
    assert_equal "TEST", io.read
    Open::S3.rm uri
  end

  def test_cp
    uri = "s3://herlab/tmp/foo.txt"

    Open::S3.write uri, "TEST"
    io = Open::S3.get_stream uri
    assert_equal "TEST", io.read
    TmpFile.with_path do |file|
      Open.cp uri, file
      assert_equal "TEST", Open.read(file)
    end
    Open::S3.rm uri
  end

  def test_write_block
    uri = "s3://herlab/tmp/foo.txt"

    Open::S3.write uri do |sin|
      sin.write "TEST"
    end
    io = Open::S3.get_stream uri
    assert_equal "TEST", io.read
    Open::S3.rm uri
  end

  def test_step
    s = Step.new "s3://herlab/var/jobs/Baking/bake_muffin_tray/Default"
    assert_include s.load, "baking"
  end

  def test_tmpfile
    require 'rbbt-util'

    TmpFile.tmpdir = Path.setup("s3://herlab/tmp")

    TmpFile.with_path "TEST" do |file|
      assert Open::S3.is_s3? file
      assert_equal "TEST", file.read
    end
  end

  def test_workflow
    m = Module.new do
      extend Workflow
      name = "TestWF"

      task :step1 => :string do
        file('foo').write('bar')
        "Step 1"
      end

      dep :step1
      task :step2 => :string do
        step(:step1).file('foo').read
      end
    end

    m.directory = Path.setup("s3://herlab/var/jobs/TestWF")

    m.job(:step2).run
    assert_include m.job(:step2).step(:step1).files, 'foo'
  end
end

