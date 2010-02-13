require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/aws'
require 'rds/rds'
require 'pp'
require File.dirname(__FILE__) + '/../test_credentials.rb'

class TestRds < Test::Unit::TestCase

    # Some of RightEc2 instance methods concerning instance launching and image registration
    # are not tested here due to their potentially risk.

    def setup
        TestCredentials.get_credentials

        @rds = Aws::Rds.new(TestCredentials.aws_access_key_id,
                            TestCredentials.aws_secret_access_key)

        @identifier = 'test-db-instance1'
        # deleting this one....
        #@identifier2 = 'my-db-instance2'
    end


    def test_01_create_db_instance
        begin
            db_instance3 = @rds.create_db_instance('right_ec2_awesome_test_key', "db.m1.small", 5, "master", "masterpass")
        rescue => ex
            #puts "msg=" + ex.message
            #puts "response=" + ex.response
            assert ex.message[0, "InvalidParameterValue".size] == "InvalidParameterValue"
        end

        #db_instance = @rds.create_db_instance(@identifier, "db.m1.small", 5, "master", "masterpass")

        tries=0
        while tries < 100
            instances_result = @rds.describe_db_instances
            instances = instances_result["DescribeDBInstancesResult"]["DBInstances"]["DBInstance"]

            #puts "INSTANCES -----> " + instances.inspect

            instances.each do |i|
                next unless i["DBInstanceIdentifier"] == @identifier
                break if i["DBInstanceStatus"] == "available"
                puts "Database not ready yet.... attempt #{tries.to_s} of 100, db state --> #{i["DBInstanceStatus"].to_s}"
                tries += 1
                sleep 5
            end


        end
    end


    def test_02_describe_db_instances
        instances_result = @rds.describe_db_instances
        #puts "instances_result=" + instances_result.inspect
        instances = instances_result["DescribeDBInstancesResult"]["DBInstances"]["DBInstance"]
        #puts "\n\ninstances count = " + instances.count.to_s + " \n\n "

        assert instances.size > 0
    end


    def test_03_describe_security_groups
        security_result = @rds.describe_db_security_groups()
        #puts "security_result=" + security_result.inspect
        security_groups=security_result["DescribeDBSecurityGroupsResult"]["DBSecurityGroups"]["DBSecurityGroup"]
        default_present = false
        if security_groups.is_a?(Array)
            security_groups.each do |security_group|
                security_group.inspect
                if security_group["DBSecurityGroupName"]=="default"
                    default_present=true
                end
            end
        else
            if security_groups["DBSecurityGroupName"]=="default"
                default_present=true
            end
        end
        assert default_present
    end


    def test_04_authorize_security_groups_ingress
        # Create
        @security_info = @rds.describe_db_security_groups({:force_array => ["DBSecurityGroup", "IPRange"]})["DescribeDBSecurityGroupsResult"]["DBSecurityGroups"]["DBSecurityGroup"]
        @rds.authorize_db_security_group_ingress_range("default", "122.122.122.122/12")

        # Check
        @security_info = @rds.describe_db_security_groups({:force_array => ["DBSecurityGroup", "IPRange"]})["DescribeDBSecurityGroupsResult"]["DBSecurityGroups"]["DBSecurityGroup"]

        ip_found = @security_info.inspect.include? "122.122.122.122/12"
        assert ip_found
    end


    def test_05_delete_db_instance
        @rds.delete_db_instance(@identifier)
        #@rds.delete_db_instance(@identifier2)
        sleep 3

        instances_result = @rds.describe_db_instances
        #puts "instances_result=" + instances_result.inspect

        instances_result["DescribeDBInstancesResult"]["DBInstances"]["DBInstance"].each do |i|
            puts "Trying to delete and getting i[DBInstanceStatus] -----------> " + i["DBInstanceStatus"]
            assert i["DBInstanceStatus"] == "deleting"
        end

        assert instances_result["DescribeDBInstancesResult"]["DBInstances"]["DBInstance"].size < 2
    end


    def test_06_create_security_groups
        group_present=false

        @rds.create_db_security_groups("new_sample_group", "new_sample_group_description")

        @security_info = @rds.describe_db_security_groups({:force_array => ["DBSecurityGroup", "IPRange"]})["DescribeDBSecurityGroupsResult"]["DBSecurityGroups"]["DBSecurityGroup"]

        @security_info.each do |security_group|
            if (security_group["DBSecurityGroupName"]=="new_sample_group")&&(security_group["DBSecurityGroupDescription"]=="new_sample_group_description")
                group_present = true
            end
        end

        assert group_present
    end


    def test_07_revoking_security_groups_ingress
        sleep 15
        @rds.revoke_db_security_group_ingress("default", "122.122.122.122/12")
        sleep 2
        @security_info = @rds.describe_db_security_groups({:force_array => ["DBSecurityGroup", "IPRange"]})["DescribeDBSecurityGroupsResult"]["DBSecurityGroups"]["DBSecurityGroup"]
        revoking = @security_info[0].inspect.include? "revoking"
        assert revoking
    end



    def test_08_delete_security_group
        group_present=false
        @rds.delete_db_security_group("new_sample_group")
        sleep 2
        @security_info = @rds.describe_db_security_groups({:force_array => ["DBSecurityGroup", "IPRange"]})["DescribeDBSecurityGroupsResult"]["DBSecurityGroups"]["DBSecurityGroup"]
        @security_info.each do |security_group|
            if (security_group["DBSecurityGroupName"]=="new_sample_group")
                group_present=true
            end
        end
        assert !group_present
    end


end