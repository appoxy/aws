require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/aws'
require 'pp'
require File.dirname(__FILE__) + '/../test_credentials.rb'

class TestElb < Test::Unit::TestCase

  def setup
    TestCredentials.get_credentials

    @ec2 = Aws::Ec2.new(TestCredentials.aws_access_key_id,
                        TestCredentials.aws_secret_access_key)

    @elb = Aws::Elb.new(TestCredentials.aws_access_key_id,
                        TestCredentials.aws_secret_access_key)
    @lb_name = 'aws-test-lb'
    @zone = 'us-east-1c'
  end

  def test_01_create_elb
    ret = @elb.create_load_balancer(@lb_name, [@zone], [{:load_balancer_port=>80, :instance_port=>8080, :protocol=>"HTTP"}])
    p ret
  end

  def test_02_register_instances

  end

  def test_03_deregister_instances

  end


  def test_04_describe_elb
    lbs = @elb.describe_load_balancers
    puts "lbs=" + lbs.inspect
    assert lbs.is_a?(Array)
    assert lbs.size > 0
    assert lbs[0][:name] == @lb_name
    assert lbs[0][:instances]
    assert lbs[0][:availability_zones][0] == @zone


  end

  def test_06_describe_instance_health

  end


  def test_15_delete_elb

  end


end
