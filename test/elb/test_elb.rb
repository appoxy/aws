require File.dirname(__FILE__) + '/test_helper.rb'
require 'pp'
require File.dirname(__FILE__) + '/../test_credentials.rb'

class TestEc2 < Test::Unit::TestCase

    # Some of RightEc2 instance methods concerning instance launching and image registration
    # are not tested here due to their potentially risk.

  def setup
    TestCredentials.get_credentials
    @ec2   = Aws::Elb.new(TestCredentials.aws_access_key_id,
                                 TestCredentials.aws_secret_access_key)
    @key   = 'right_ec2_awesome_test_key'
    @group = 'right_ec2_awesome_test_security_group'
  end

  def test_01_create_elb
    
  end

  def test_02_register_instances
    assert @ec2.create_security_group(@group,'My awesone test group'), 'Create_security_group fail'
    group = @ec2.describe_security_groups([@group])[0]
    assert_equal @group, group[:aws_group_name], 'Group must be created but does not exist'
  end

  def test_03_deregister_instances
    assert @ec2.authorize_security_group_named_ingress(@group, TestCredentials.account_number, 'default')
    assert @ec2.authorize_security_group_IP_ingress(@group, 80,80,'udp','192.168.1.0/8')
  end

  def test_04_describe_instance_health
    assert_equal 2, @ec2.describe_security_groups([@group])[0][:aws_perms].size
  end

  def test_05_describe_elb
    assert @ec2.revoke_security_group_IP_ingress(@group, 80,80,'udp','192.168.1.0/8')
    assert @ec2.revoke_security_group_named_ingress(@group,
                                                    TestCredentials.account_number, 'default')
  end

  def test_06_delete_elb
    images = @ec2.describe_images
    assert images.size>0, 'Amazon must have at least some public images'
      # unknown image
    assert_raise(Aws::AwsError){ @ec2.describe_images(['ami-ABCDEFGH'])}
  end


end
