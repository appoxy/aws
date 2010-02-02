require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/aws'
require 'rds/rds'
require 'pp'
require File.dirname(__FILE__) + '/../test_credentials.rb'

class TestElb < Test::Unit::TestCase

    # Some of RightEc2 instance methods concerning instance launching and image registration
    # are not tested here due to their potentially risk.

    def setup
        TestCredentials.get_credentials

        @rds = Aws::Rds.new(TestCredentials.aws_access_key_id,
                            TestCredentials.aws_secret_access_key)

        @identifier = 'my-db-instance'
         @identifier2 = 'my-db-instance2'

    end

    def test_01_create_db_instance


        begin
            db_instance2 = @rds.create_db_instance('right_ec2_awesome_test_key', "db.m1.small", 5, "master", "masterpass")
        rescue => ex
            puts "msg=" + ex.message
            puts "response=" + ex.response
            assert ex.message[0,"InvalidParameterValue".size] == "InvalidParameterValue"
        end

        db_instance = @rds.create_db_instance(@identifier, "db.m1.small", 5, "master", "masterpass")
        puts 'db_instance=' + db_instance.inspect

        db_instance2 = @rds.create_db_instance(@identifier2, "db.m1.small", 5, "master", "masterpass")
        puts 'db_instance2=' + db_instance2.inspect

        sleep 10
        

    end

    def test_02_describe_db_instances
        instances_result = @rds.describe_db_instances
        puts "instances_result=" + instances_result.inspect
        instances = instances_result["DescribeDBInstancesResult"]["DBInstances"]["DBInstance"]
        puts 'instances=' + instances.inspect
        assert instances.size == 2
    end

    def test_06_delete_db_instance

        @rds.delete_db_instance(@identifier)
        @rds.delete_db_instance(@identifier2)

        sleep 2

        instances_result = @rds.describe_db_instances
        puts "instances_result=" + instances_result.inspect
        instances_result["DescribeDBInstancesResult"]["DBInstances"]["DBInstance"].each do |i|
            assert i["DBInstanceStatus"] == "deleting"
        end
#        assert instances_result["DescribeDBInstancesResult"]["DBInstances"]["DBInstance"].size == 0

    end


end
