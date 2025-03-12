require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

class TestTerraform < Test::Unit::TestCase

  def aws_provider_info_from_ENV
    {:region => ENV["AWS_REGION"], :access_key => ENV["AWS_KEY"], :secret_key => ENV["AWS_SECRET"]}
  end


  def _test_output_format
    terraform = TerraformDSL.new
    terraform.add :aws, :host,
                  :outputs => { :aws_instance_ip => :ip }

    with_tmp_file do |tmpconfig|
      FileUtils.mkdir tmpconfig
      terraform.config tmpconfig
      assert File.read(tmpconfig + '/host.aws_host.outputs.tf')
                 .include?('output "aws_host_ip"')
    end

    terraform = TerraformDSL.new
    terraform.add :aws, :host,
                  :outputs => :all

    with_tmp_file do |tmpconfig|
      FileUtils.mkdir tmpconfig
      terraform.config tmpconfig
      assert File.read(tmpconfig + '/host.aws_host.outputs.tf')
                 .include?('output "aws_host_aws_instance_ip"')
    end

    terraform = TerraformDSL.new
    terraform.add :aws, :host,
                  :outputs => [:all]

    with_tmp_file do |tmpconfig|
      FileUtils.mkdir tmpconfig
      terraform.config tmpconfig
      assert File.read(tmpconfig + '/host.aws_host.outputs.tf')
                 .include?('output "aws_host_aws_instance_ip"')
    end

    terraform = TerraformDSL.new
    terraform.add :aws, :host,
                  :outputs => [:all, { :aws_instance_ip => :ip }]

    with_tmp_file do |tmpconfig|
      FileUtils.mkdir tmpconfig
      terraform.config tmpconfig
      assert File.read(tmpconfig + '/host.aws_host.outputs.tf')
                 .include?('output "aws_host_ip"')
      assert File.read(tmpconfig + '/host.aws_host.outputs.tf')
                 .include?('output "aws_host_aws_instance_ip"')
    end
  end

  def _test_plan
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    terraform.add :aws, :host, :name => 'host1',
      :host_nametag => 'TEST-PRO-Host1',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 't2.micro',
      :outputs => { :aws_instance_ip => :ip }

    config_dir = terraform.config
    deployment = TerraformDSL::Deployment.new config_dir

    begin
      deployment.plan
      assert true
    rescue StandardError
      Log.exception $!
      assert false
    end
  end

  def _test_empty_deployment
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = Open.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    config_dir = terraform.config
    deployment = TerraformDSL::Deployment.new config_dir

    deployment.with_deployment do
      assert_match "Ubuntu", deployment.element_state("module.aws_provider.data.aws_ami.ubuntu2004")
    end
  end


  def test_simple_deployment
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    host1 = terraform.add :aws, :host, :name => 'host1',
      :host_nametag => 'TEST-Host1',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 't2.micro',
      :outputs => { :aws_instance_ip => :ip }

    config_dir = terraform.config
    deployment = TerraformDSL::Deployment.new config_dir

    deployment.plan
    deployment.with_deployment do
      assert deployment.outputs.include?('host1_ip')
      assert_equal 4, deployment.output('host1', 'ip').split('.').length
      assert_equal 4, deployment.output(host1, 'ip').split('.').length
    end
  end

  def _test_simple_deployment_save_load
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV
    terraform.add :aws, :host, :name => 'host1',
      :host_nametag => 'TEST-Host1',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 't2.micro',
      :outputs => { :aws_instance_ip => :ip }

    config_dir = terraform.config
    deployment = TerraformDSL::Deployment.new config_dir

    deployment.with_deployment do
      deployment.with_bundle do |tmp_file|
        deployment2 = TerraformDSL::Deployment.load tmp_file

        assert_equal deployment.provisioned_elements, deployment2.provisioned_elements

        deployment2.destroy
        deployment.refresh

        assert deployment2.provisioned_elements.empty?
        assert deployment.provisioned_elements.reject {|e| e.include? '.data.' }.empty?
      end
    end
  end

  def _test_double_deployment
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    terraform.add :aws, :host, :name => 'host1',
      :host_nametag => 'TEST-PRO-Host1',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 'c5.metal',
      :outputs => { :aws_instance_ip => :ip }

    host2 = terraform.add :aws, :host, :name => 'host2',
      :host_nametag => 'TEST-PRO-Host2',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 'c5.metal',
      :outputs => { :aws_instance_ip => :ip }

    config_dir = terraform.config
    deployment = TerraformDSL::Deployment.new config_dir

    deployment.with_deployment do
      assert deployment.outputs.include?('host1_ip')
      assert deployment.outputs.include?('host2_ip')
      assert_equal 4, deployment.output('host2', 'ip').split('.').length
      assert_equal 4, deployment.output(host2, 'ip').split('.').length
    end
  end

  def _test_incremental_deployment
    terraform = TerraformDSL.new

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    config_dir = terraform.config
    deployment = TerraformDSL::Deployment.new config_dir

    begin
      deployment.apply

      terraform.add :aws, :host, :name => 'host1',
        :host_nametag => 'TEST-PRO-Host1',
        :ami => provider.default_ami,
        :instance_type => 't2.micro',
        :outputs => { :aws_instance_ip => :ip }

      terraform.config config_dir
      deployment.update

      assert deployment.outputs.include?('host1_ip')
      assert_equal 4, deployment.output('host1', 'ip').split('.').length

      host2 = terraform.add :aws, :host, :name => 'host2',
        :host_nametag => 'TEST-PRO-Host2',
        :ami => provider.default_ami,
        :instance_type => 't2.micro',
        :outputs => { :aws_instance_ip => :ip }

      terraform.config config_dir
      deployment.update

      assert deployment.outputs.include?('host1_ip')
      assert deployment.outputs.include?('host2_ip')
      assert_equal 4, deployment.output('host2', 'ip').split('.').length
      assert_equal 4, deployment.output(host2, 'ip').split('.').length
    ensure
      deployment.destroy
    end
  end

  def _test_simple_host_register
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    host1 = terraform.add :aws, :host, :name => 'host1',
      :host_nametag => 'TEST-PRO-Host_1',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 'c5.metal',
      :outputs => :all

    config_dir = terraform.config

    deployment = TerraformDSL::Deployment.new config_dir

    deployment.plan

    deployment.with_deployment do
      ip = deployment.output host1, :aws_instance_ip
      assert_equal 'ubuntu', `ssh ubuntu@#{ip} whoami`.strip
    end
  end

  def _test_cluster_register
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    cluster = terraform.add :aws, :cluster

    host1 = terraform.add :aws, :host, :name => 'host',
      :host_nametag => 'TEST-PRO-Host',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :subnet_id => cluster.aws_subnet_id,
      :vpc_security_group_ids => [cluster.aws_security_group_id],
      :private_ip => '10.0.0.5',
      :instance_type => 'c5.metal',
      :outputs => :all

    configure1 = terraform.add :opennebula, :configure, :name => 'configure',
      :ip => host1.aws_instance_ip,
      :file => File.join(TerraformDSL::ANSIBLE_DIR, 'aws.yml')

    config_dir = terraform.config

    deployment = TerraformDSL::Deployment.new config_dir

    deployment.with_deployment do
      ip = deployment.output host1, :aws_instance_ip
      assert_equal 'ubuntu', `ssh ubuntu@#{ip} whoami`.strip
    end
  end

  def _test_multiple_configure
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    host1 = terraform.add :aws, :host, :name => 'host1',
      :host_nametag => 'TEST-PRO-Host_1',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 'c5.metal',
      :outputs => :all

    host2 = terraform.add :aws, :host, :name => 'host2',
      :host_nametag => 'TEST-PRO-Host_2',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 'c5.metal',
      :outputs => :all

    config_dir = terraform.config

    deployment = TerraformDSL::Deployment.new config_dir

    deployment.with_deployment do
      ip1 = deployment.output host1, :aws_instance_ip
      ip2 = deployment.output host2, :aws_instance_ip
      assert_equal 'ubuntu', `ssh ubuntu@#{ip1} whoami`.strip
      assert_equal 'ubuntu', `ssh ubuntu@#{ip2} whoami`.strip
    end
  end

  def _test_multiple_register
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    one_provider terraform

    host1 = terraform.add :aws, :host, :name => 'host1',
      :host_nametag => 'TEST-PRO-Host_1',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 'c5.metal',
      :outputs => :all

    host2 = terraform.add :aws, :host, :name => 'host2',
      :host_nametag => 'TEST-PRO-Host_2',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 'c5.metal',
      :outputs => :all

    configure = terraform.add :opennebula, :configure,
                              :ip_list => [host1.aws_instance_ip, host2.aws_instance_ip],
                              :file => File.join(TerraformDSL::ANSIBLE_DIR, 'aws.yml')

    terraform.add :opennebula, :register_host,
                  :ip_list => [host1.aws_instance_ip, host2.aws_instance_ip],
                  :depends_on => [configure],
                  :deployment_id => 'one-provision-deployment_test_multiple_register',
                  :virtualization_type => 'kvm'

    config_dir = terraform.config

    deployment = TerraformDSL::Deployment.new config_dir

    deployment.with_deployment do
      ip1 = deployment.output host1, :aws_instance_ip
      ip2 = deployment.output host2, :aws_instance_ip
      assert_equal 'ubuntu', `ssh ubuntu@#{ip1} whoami`.strip
      assert_equal 'ubuntu', `ssh ubuntu@#{ip2} whoami`.strip
    end
  end

  def _test_datastore_registry
    terraform = TerraformDSL.new

    deployment_id = "one-provision-deployment-#{__method__}"

    one_provider terraform

    cluster = terraform.add :opennebula, :register_cluster,
                            :deployment_id => deployment_id

    terraform.add :opennebula, :register_datastores,
                  :cluster_ids => [cluster.cluster_id],
                  :deployment_id => deployment_id

    terraform.add :opennebula, :register_network,
                  :cluster_ids => [cluster.cluster_id],
                  :deployment_id => deployment_id

    config_dir = terraform.config

    deployment = TerraformDSL::Deployment.new config_dir

    deployment.with_deployment do
      assert true
    end
  end

  def _test_wrong_aws_key
    terraform = TerraformDSL.new

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    terraform.add :aws, :host, :name => 'host1',
      :host_nametag => 'TEST-PRO-Host1',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 't2.micro',
      :outputs => { :aws_instance_ip => :ip }


    config_dir = terraform.config

    deployment = TerraformDSL::Deployment.new config_dir

    assert_raise TerraformDSL::Deployment::TerraformException do 
      deployment.plan 
    end
  end

  def _test_wrong_one_login
    terraform = TerraformDSL.new

    deployment_id = "one-provision-deployment-#{__method__}"

    terraform.provider :opennebula,
                       :source => 'OpenNebula/opennebula',
                       :endpoint => one_provider_info_from_ENV["endpoint"],
                       :username => 'wrong_user',
                       :password => 'wrong_password'

    cluster = terraform.add :opennebula, :register_cluster,
                            :deployment_id => deployment_id

    terraform.add :opennebula, :register_datastores,
                  :cluster_ids => [cluster.cluster_id],
                  :deployment_id => deployment_id

    config_dir = terraform.config

    deployment = TerraformDSL::Deployment.new config_dir

    assert_raise TerraformDSL::Deployment::TerraformException do 
      deployment.plan 
    end
  end

  def _test_cluster_complete_registry
    terraform = TerraformDSL.new

    deployment_id = "one-provision-deployment-#{__method__}"

    ssh_key_file = "#{Dir.home}/.ssh/id_rsa.pub"
    ssh_key = File.read(ssh_key_file).strip

    provider = terraform.provider :aws, aws_provider_info_from_ENV

    one_provider terraform

    host1 = terraform.add :aws, :host, :name => 'host1',
      :host_nametag => 'TEST-PRO-Host_1',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 'c5.metal',
      :outputs => :all

    host2 = terraform.add :aws, :host, :name => 'host2',
      :host_nametag => 'TEST-PRO-Host_2',
      :ssh_key => ssh_key,
      :ami => provider.default_ami,
      :instance_type => 'c5.metal',
      :outputs => :all

    configure = terraform.add :opennebula, :configure,
                              :ip_list => [host1.aws_instance_ip, host2.aws_instance_ip],
                              :file => File.join(TerraformDSL::ANSIBLE_DIR, 'aws.yml')

    cluster = terraform.add :opennebula, :register_cluster,
                            :deployment_id => deployment_id

    terraform.add :opennebula, :register_host,
                  :ip_list => [host1.aws_instance_ip, host2.aws_instance_ip],
                  :depends_on => [configure],
                  :cluster_id => cluster.cluster_id,
                  :deployment_id => deployment_id,
                  :virtualization_type => 'kvm'

    terraform.add :opennebula, :register_datastores,
                  :cluster_ids => [cluster.cluster_id],
                  :deployment_id => deployment_id

    network = terraform.add :opennebula, :register_network,
                  :cluster_ids => [cluster.cluster_id],
                  :deployment_id => deployment_id

    #    terraform.add :opennebula, :register_ip,
    #                  :network_id => [network.public_id],
    #                  :ipam => provider.ipam
    #
    config_dir = terraform.config

    deployment = TerraformDSL::Deployment.new config_dir
    deployment.plan

    deployment.with_deployment do
      ip1 = deployment.output host1, :aws_instance_ip
      ip2 = deployment.output host2, :aws_instance_ip
      assert_equal 'ubuntu', `ssh ubuntu@#{ip1} whoami`.strip
      assert_equal 'ubuntu', `ssh ubuntu@#{ip2} whoami`.strip
    end
  end
end
