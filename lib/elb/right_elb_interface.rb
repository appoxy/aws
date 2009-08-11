module RightAws



    class Elb < RightAwsBase
        include RightAwsBaseInterface


        #Amazon EC2 API version being used
        API_VERSION       = "2008-12-01"
        DEFAULT_HOST      = "elasticloadbalancing.amazonaws.com"
        DEFAULT_PATH      = '/'
        DEFAULT_PROTOCOL  = 'http'
        DEFAULT_PORT      = 80


        @@bench = AwsBenchmarkingBlock.new
        def self.bench_xml
            @@bench.xml
        end
        def self.bench_ec2
            @@bench.service
        end

        # Current API version (sometimes we have to check it outside the GEM).
        @@api = ENV['EC2_API_VERSION'] || API_VERSION
        def self.api
            @@api
        end


        def initialize(aws_access_key_id=nil, aws_secret_access_key=nil, params={})
            init({ :name             => 'ELB',
                   :default_host     => ENV['ELB_URL'] ? URI.parse(ENV['ELB_URL']).host   : DEFAULT_HOST,
                   :default_port     => ENV['ELB_URL'] ? URI.parse(ENV['ELB_URL']).port   : DEFAULT_PORT,
                   :default_service  => ENV['ELB_URL'] ? URI.parse(ENV['ELB_URL']).path   : DEFAULT_PATH,
                   :default_protocol => ENV['ELB_URL'] ? URI.parse(ENV['ELB_URL']).scheme : DEFAULT_PROTOCOL },
                 aws_access_key_id    || ENV['AWS_ACCESS_KEY_ID'],
                 aws_secret_access_key|| ENV['AWS_SECRET_ACCESS_KEY'],
                 params)
        end


        def generate_request(action, params={})
            service_hash = {"Action"         => action,
                            "AWSAccessKeyId" => @aws_access_key_id,
                            "Version"        => @@api }
            service_hash.update(params)
            service_params = signed_service_params(@aws_secret_access_key, service_hash, :get, @params[:server], @params[:service])

            # use POST method if the length of the query string is too large
            if service_params.size > 2000
                if signature_version == '2'
                    # resign the request because HTTP verb is included into signature
                    service_params = signed_service_params(@aws_secret_access_key, service_hash, :post, @params[:server], @params[:service])
                end
                request      = Net::HTTP::Post.new(service)
                request.body = service_params
                request['Content-Type'] = 'application/x-www-form-urlencoded'
            else
                request        = Net::HTTP::Get.new("#{@params[:service]}?#{service_params}")
            end

            #puts "\n\n --------------- QUERY REQUEST TO AWS -------------- \n\n"
            #puts "#{@params[:service]}?#{service_params}\n\n"

            # prepare output hash
            { :request  => request,
              :server   => @params[:server],
              :port     => @params[:port],
              :protocol => @params[:protocol] }
        end


        # Sends request to Amazon and parses the response
        # Raises AwsError if any banana happened
        def request_info(request, parser)
            thread = @params[:multi_thread] ? Thread.current : Thread.main
            thread[:elb_connection] ||= Rightscale::HttpConnection.new(:exception => RightAws::AwsError, :logger => @logger)
            request_info_impl(thread[:elb_connection], @@bench, request, parser)
        end


        #-----------------------------------------------------------------
        #      REQUESTS
        #-----------------------------------------------------------------


        def register_instance_with_elb(instance_id, lparams={})
            params = {}

            params['LoadBalancerName']                  = lparams[:load_balancer_name]
            params['Instances.member.1.InstanceId']     = instance_id

            @logger.info("Registering Instance #{instance_id} with Load Balancer '#{params['LoadBalancerName']}'")

            link = generate_request("RegisterInstancesWithLoadBalancer", params)
            resp = request_info(link, QElbRegisterInstanceParser.new(:logger => @logger))

        rescue Exception
            on_exception
        end






        def describe_load_balancers
            @logger.info("Describing Load Balancers")

            params = {}

            link = generate_request("DescribeLoadBalancers", params)

            resp = request_info(link, QElbDescribeLoadBalancersParser.new(:logger => @logger))

        rescue Exception
            on_exception
        end




        #-----------------------------------------------------------------
        #      PARSERS: Instances
        #-----------------------------------------------------------------

        class QElbDescribeLoadBalancersParser < RightAWSParser

            def reset
                @result = []
            end


            def tagend(name)
                #case name
                #    when 'LoadBalancerName' then
                #        @result[:load_balancer_name]        = @text
                #    when 'AvailabilityZones' then
                #        @result[:availability_zones]        = @text
                #    when 'CreatedTime' then
                #        @result[:created_time] =            Time.parse(@text)
                #    when 'DNSName' then
                #        @result[:dns_name]                  = @text
                #    when 'Instances' then
                #        @result[:instances]                 = @text
                #    when 'HealthCheck' then
                #        @result[:health_check]              = @text
                #    when 'Listeners' then
                #        @result[:listeners]                  = @text
                #end
            end
        end

        class QElbRegisterInstanceParser < RightAWSParser

            def reset
                @result = []
            end


            def tagend(name)
                #case name
                #    when 'LoadBalancerName' then
                #        @result[:load_balancer_name]        = @text
                #    when 'AvailabilityZones' then
                #        @result[:availability_zones]        = @text
                #    when 'CreatedTime' then
                #        @result[:created_time] =            Time.parse(@text)
                #    when 'DNSName' then
                #        @result[:dns_name]                  = @text
                #    when 'Instances' then
                #        @result[:instances]                 = @text
                #    when 'HealthCheck' then
                #        @result[:health_check]              = @text
                #    when 'Listeners' then
                #        @result[:listeners]                  = @text
                #end
            end
        end




    end


end