module Aws
    require 'xmlsimple'

    # API Reference: http://docs.amazonwebservices.com/AmazonRDS/latest/APIReference/
    class Rds < AwsBase
        include AwsBaseInterface


        # Amazon API version being used
        API_VERSION = nil
        DEFAULT_HOST = "rds.amazonaws.com"
        DEFAULT_PATH = '/'
        DEFAULT_PROTOCOL = 'https'
        DEFAULT_PORT = 443

        @@api = ENV['RDS_API_VERSION'] || API_VERSION


        def self.api
            @@api
        end


        @@bench = AwsBenchmarkingBlock.new


        def self.bench_xml
            @@bench.xml
        end


        def self.bench_ec2
            @@bench.service
        end


        def initialize(aws_access_key_id=nil, aws_secret_access_key=nil, params={})
            uri = ENV['RDS_URL'] ? URI.parse(ENV['RDS_URL']) : nil
            init({ :name => 'RDS',
                   :default_host => uri ? uri.host : DEFAULT_HOST,
                   :default_port => uri ? uri.port : DEFAULT_PORT,
                   :default_service => uri ? uri.path : DEFAULT_PATH,
                   :default_protocol => uri ? uri.scheme : DEFAULT_PROTOCOL },
                 aws_access_key_id || ENV['AWS_ACCESS_KEY_ID'],
                 aws_secret_access_key|| ENV['AWS_SECRET_ACCESS_KEY'],
                 params)
        end


        def generate_request(action, params={})
            generate_request2(@aws_access_key_id, @aws_secret_access_key, action, @@api, @params, params)
        end


        #-----------------------------------------------------------------
        #      REQUESTS
        #-----------------------------------------------------------------

        #
        # identifier: db instance identifier. Must be unique per account per zone.
        # instance_class: db.m1.small | db.m1.large | db.m1.xlarge | db.m2.2xlarge | db.m2.4xlarge
        # See this for other values: http://docs.amazonwebservices.com/AmazonRDS/latest/APIReference/
        #
        # options:
        #    db_name: if you want a database created at the same time as the instance, specify :db_name option.
        #    availability_zone: default is random zone.
        def create_db_instance(identifier, instance_class, allocated_storage, master_username, master_password, options={})
            params = {}
            params['DBInstanceIdentifier'] = identifier
            params['DBInstanceClass'] = instance_class
            params['AllocatedStorage'] = allocated_storage
            params['MasterUsername'] = master_username
            params['MasterUserPassword'] = master_password

            params['Engine'] = options[:engine] || "MySQL5.1"
            params['DBName'] = options[:db_name] if options[:db_name]
            params['AvailabilityZone'] = options[:availability_zone] if options[:availability_zone]
            params['PreferredMaintenanceWindow'] = options[:preferred_maintenance_window] if options[:preferred_maintenance_window]
            params['BackupRetentionPeriod'] = options[:preferred_retention_period] if options[:preferred_retention_period]
            params['PreferredBackupWindow'] = options[:preferred_backup_window] if options[:preferred_backup_window]

            @logger.info("Creating DB Instance called #{identifier}")

            link = generate_request("CreateDBInstance", params)
            resp = request_info_xml_simple(:rds_connection, @params, link, @logger)

        rescue Exception
            on_exception
        end


        # options:
        #      DBInstanceIdentifier
        #      MaxRecords
        #      Marker
        def describe_db_instances(options={})
            params = {}
            params['DBInstanceIdentifier'] = options[:DBInstanceIdentifier] if options[:DBInstanceIdentifier]
            params['MaxRecords'] = options[:MaxRecords] if options[:MaxRecords]
            params['Marker'] = options[:Marker] if options[:Marker]

            link = generate_request("DescribeDBInstances", params)
            resp = request_info_xml_simple(:rds_connection, @params, link, @logger)

        rescue Exception
            on_exception
        end


        # identifier: identifier of db instance to delete.
        # final_snapshot_identifier: if specified, RDS will crate a final snapshot before deleting so you can restore it later.
        def delete_db_instance(identifier, final_snapshot_identifier=nil)
            @logger.info("Deleting DB Instance - " + identifier.to_s)

            params = {}
            params['DBInstanceIdentifier'] = identifier
            if final_snapshot_identifier
                params['FinalDBSnapshotIdentifier'] = final_snapshot_identifier
            else
                params['SkipFinalSnapshot'] = true
            end

            link = generate_request("DeleteDBInstance", params)
            resp = request_info_xml_simple(:rds_connection, @params, link, @logger)

        rescue Exception
            on_exception
        end


        def create_db_security_groups(group_name, description, options={})
            params = {}
            params['DBSecurityGroupName'] = group_name
            params['DBSecurityGroupDescription'] = description
            params['Engine'] = options[:engine] || "MySQL5.1"
            link = generate_request("CreateDBSecurityGroup", params)
            resp = request_info_xml_simple(:rds_connection, @params, link, @logger)
        rescue Exception
            on_exception
        end


        def delete_db_security_group(group_name, options={})
            params = {}
            params['DBSecurityGroupName'] = group_name
            link = generate_request("DeleteDBSecurityGroup", params)
            resp = request_info_xml_simple(:rds_connection, @params, link, @logger)
        rescue Exception
            on_exception
        end


        def describe_db_security_groups(options={})
            params = {}
            params['DBSecurityGroupName'] = options[:DBSecurityGroupName] if options[:DBSecurityGroupName]
            params['MaxRecords'] = options[:MaxRecords] if options[:MaxRecords]

            force_array = options[:force_array].nil? ? false : options[:force_array]

            link = generate_request("DescribeDBSecurityGroups", params)
            resp = request_info_xml_simple(:rds_connection, @params, link, @logger, :force_array => force_array)
        rescue Exception
            on_exception
        end


        def authorize_db_security_group_ingress_ec2group(group_name, ec2_group_name, ec2_group_owner_id, options={})
            params = {}
            params['DBSecurityGroupName'] = group_name
            params['EC2SecurityGroupOwnerId'] = ec2_group_owner_id
            params['EC2SecurityGroupName'] = ec2_group_name
            link = generate_request("AuthorizeDBSecurityGroupIngress", params)
            resp = request_info_xml_simple(:rds_connection, @params, link, @logger)
        rescue Exception
            on_exception
        end


        def authorize_db_security_group_ingress_range(group_name, ip_range, options={})
            params = {}
            params['DBSecurityGroupName'] = group_name
            params['CIDRIP'] = ip_range
            link = generate_request("AuthorizeDBSecurityGroupIngress", params)
            resp = request_info_xml_simple(:rds_connection, @params, link, @logger)
        rescue Exception
            on_exception
        end


        def revoke_db_security_group_ingress(group_name, ip_range, options={})
            params = {}
            params['DBSecurityGroupName'] = group_name
            params['CIDRIP'] = ip_range
            link = generate_request("RevokeDBSecurityGroupIngress", params)
            resp = request_info_xml_simple(:rds_connection, @params, link, @logger)
        rescue Exception
            on_exception
        end


    end

end