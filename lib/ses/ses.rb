require_relative "../awsbase/awsbase"
module Aws

  require 'xmlsimple'

  class Ses < AwsBase

    include AwsBaseInterface

    API_VERSION = "2010-12-01"
    DEFAULT_HOST = "email.us-east-1.amazonaws.com"
    DEFAULT_PATH = '/'
    DEFAULT_PROTOCOL = 'https'
    DEFAULT_PORT = 443

    def self.connection_name
      :ses_connection
    end

    @@bench = AwsBenchmarkingBlock.new

    def self.bench
      @@bench
    end

    def self.bench_xml
      @@bench.xml
    end

    def self.bench_ec2
      @@bench.service
    end

    # Current API version (sometimes we have to check it outside the GEM).
    @@api = ENV['SES_API_VERSION'] || API_VERSION

    def self.api
      @@api
    end


    def initialize(aws_access_key_id=nil, aws_secret_access_key=nil, params={})
      init({:name => 'SES',
            :default_host => ENV['SES_URL'] ? URI.parse(ENV['SES_URL']).host : DEFAULT_HOST,
            :default_port => ENV['SES_URL'] ? URI.parse(ENV['SES_URL']).port : DEFAULT_PORT,
            :default_service => ENV['SES_URL'] ? URI.parse(ENV['SES_URL']).path : DEFAULT_PATH,
            :default_protocol => ENV['SES_URL'] ? URI.parse(ENV['SES_URL']).scheme : DEFAULT_PROTOCOL,
            :api_version => API_VERSION,
            :signature_version=>'3'},
           aws_access_key_id || ENV['AWS_ACCESS_KEY_ID'],
           aws_secret_access_key|| ENV['AWS_SECRET_ACCESS_KEY'],
           params)
    end

    def do_request(action, params, options={})
      link = generate_request(action, params)
      puts "request=" + link[:request].inspect
      resp = request_info_xml_simple3(self, link,
                                      :group_tags =>{"LoadBalancersDescriptions"=>"LoadBalancersDescription",
                                                     "DBParameterGroups" =>"DBParameterGroup",
                                                     "DBSecurityGroups" =>"DBSecurityGroup",
                                                     "EC2SecurityGroups" =>"EC2SecurityGroup",
                                                     "IPRanges" =>"IPRange"},
                                      :force_array =>["DBInstances",
                                                      "DBParameterGroups",
                                                      "DBSecurityGroups",
                                                      "EC2SecurityGroups",
                                                      "IPRanges"],
                                      :pull_out_array =>options[:pull_out_array],
                                      :pull_out_single=>options[:pull_out_single],
                                      :wrapper =>options[:wrapper])
    end


    #-----------------------------------------------------------------
    #      REQUESTS
    #-----------------------------------------------------------------


    # options:
    #    :marker => value received from previous response if IsTruncated = true
    #    :max_items => number of items you want returned
    #    :path_previx => for filtering results, default is /
    def get_send_quota(options={})
      @logger.info("get_send_quota")

      resp = do_request("GetSendQuota", options)


    rescue Exception
      on_exception
    end

    #
    # name: name of certificate
    # public_key: public key certificate in PEM-encoded format
    # private_key: private key in PEM-encoded format
    # options:
    #    :path => specify a path you want it stored in
    #    :certificate_chain => contents of certificate chain
    def upload_server_certificate(name, public_key, private_key, options={})
      params = {}
      params['ServerCertificateName'] = name
      params['PrivateKey'] = private_key
      params['CertificateBody'] = public_key

      params['CertificateChain'] = options[:certificate_chain] if options[:certificate_chain]
      params['Path'] = options[:path] if options[:path]

      p params

      resp = do_request("UploadServerCertificate", params, :pull_out_array=>[:list_server_certificates_result, :server_certificate_metadata_list])


    rescue Exception
      on_exception
    end


  end


end