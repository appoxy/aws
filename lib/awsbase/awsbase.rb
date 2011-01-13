#
# Copyright (c) 2007-2008 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# Test
module Aws
  require 'digest/md5'
  require 'pp'
  require 'cgi'
  require 'uri'
  require 'xmlsimple'
  require 'active_support/core_ext'

  require_relative 'utils'
  require_relative 'errors'
  require_relative 'parsers'


  class AwsBenchmarkingBlock #:nodoc:
    attr_accessor :xml, :service

    def initialize
      # Benchmark::Tms instance for service (Ec2, S3, or SQS) access benchmarking.
      @service = Benchmark::Tms.new()
      # Benchmark::Tms instance for XML parsing benchmarking.
      @xml     = Benchmark::Tms.new()
    end
  end

  class AwsNoChange < RuntimeError
  end

  class AwsBase

    # Amazon HTTP Error handling

    # Text, if found in an error message returned by AWS, indicates that this may be a transient
    # error. Transient errors are automatically retried with exponential back-off.
    AMAZON_PROBLEMS   = ['internal service error',
                         'is currently unavailable',
                         'no response from',
                         'Please try again',
                         'InternalError',
                         'ServiceUnavailable', #from SQS docs
                         'Unavailable',
                         'This application is not currently available',
                         'InsufficientInstanceCapacity'
    ]
    @@amazon_problems = AMAZON_PROBLEMS
    # Returns a list of Amazon service responses which are known to be transient problems.
    # We have to re-request if we get any of them, because the problem will probably disappear.
    # By default this method returns the same value as the AMAZON_PROBLEMS const.
    def self.amazon_problems
      @@amazon_problems
    end

    # Sets the list of Amazon side problems.  Use in conjunction with the
    # getter to append problems.
    def self.amazon_problems=(problems_list)
      @@amazon_problems = problems_list
    end

  end

  module AwsBaseInterface

    DEFAULT_SIGNATURE_VERSION = '2'

    module ClassMethods

      def self.bench
        @@bench
      end

      def self.bench
        @@bench
      end

      def self.bench_xml
        @@bench.xml
      end

      def self.bench_s3
        @@bench.service
      end
    end

    @@caching = false

    def self.caching
      @@caching
    end

    def self.caching=(caching)
      @@caching = caching
    end

    # Current aws_access_key_id
    attr_reader :aws_access_key_id
    # Last HTTP request object
    attr_reader :last_request
    # Last HTTP response object
    attr_reader :last_response
    # Last AWS errors list (used by AWSErrorHandler)
    attr_accessor :last_errors
    # Last AWS request id (used by AWSErrorHandler)
    attr_accessor :last_request_id
    # Logger object
    attr_accessor :logger
    # Initial params hash
    attr_accessor :params
    # RightHttpConnection instance
    # there's a method now to get this since it could be per thread or what have you
    # attr_reader :connection
    # Cache
    attr_reader :cache
    # Signature version (all services except s3)
    attr_reader :signature_version

    def init(service_info, aws_access_key_id, aws_secret_access_key, params={}) #:nodoc:
      @params = params
      raise AwsError.new("AWS access keys are required to operate on #{service_info[:name]}") \
 if aws_access_key_id.blank? || aws_secret_access_key.blank?
      @aws_access_key_id     = aws_access_key_id
      @aws_secret_access_key = aws_secret_access_key
      # if the endpoint was explicitly defined - then use it
      if @params[:endpoint_url]
        @params[:server]   = URI.parse(@params[:endpoint_url]).host
        @params[:port]     = URI.parse(@params[:endpoint_url]).port
        @params[:service]  = URI.parse(@params[:endpoint_url]).path
        @params[:protocol] = URI.parse(@params[:endpoint_url]).scheme
        @params[:region]   = nil
      else
        @params[:server] ||= service_info[:default_host]
        @params[:server] = "#{@params[:region]}.#{@params[:server]}" if @params[:region]
        @params[:port]        ||= service_info[:default_port]
        @params[:service]     ||= service_info[:default_service]
        @params[:protocol]    ||= service_info[:default_protocol]
        @params[:api_version] ||= service_info[:api_version]
      end
      if !@params[:multi_thread].nil? && @params[:connection_mode].nil? # user defined this
        @params[:connection_mode] = @params[:multi_thread] ? :per_thread : :single
      end
#      @params[:multi_thread] ||= defined?(AWS_DAEMON)
      @params[:connection_mode] ||= :default
      @params[:connection_mode] = :per_request if @params[:connection_mode] == :default
      @logger = @params[:logger]
      @logger = Rails.logger if !@logger && defined?(Rails) && defined?(Rails.logger)
      @logger = ::Rails.logger if !@logger && defined?(::Rails.logger)
      @logger = Logger.new(STDOUT) if !@logger
      @logger.info "New #{self.class.name} using #{@params[:connection_mode].to_s}-connection mode"
      @error_handler     = nil
      @cache             = {}
      @signature_version = (params[:signature_version] || DEFAULT_SIGNATURE_VERSION).to_s
    end

    def signed_service_params(aws_secret_access_key, service_hash, http_verb=nil, host=nil, service=nil)
      case signature_version.to_s
        when '0' then
          AwsUtils::sign_request_v0(aws_secret_access_key, service_hash)
        when '1' then
          AwsUtils::sign_request_v1(aws_secret_access_key, service_hash)
        when '2' then
          AwsUtils::sign_request_v2(aws_secret_access_key, service_hash, http_verb, host, service)
        else
          raise AwsError.new("Unknown signature version (#{signature_version.to_s}) requested")
      end
    end

    def generate_request(action, params={})
      generate_request2(@aws_access_key_id, @aws_secret_access_key, action, @params[:api_version], @params, params)
    end

    # FROM SDB
    def generate_request2(aws_access_key, aws_secret_key, action, api_version, lib_params, user_params={}, options={}) #:nodoc:
      # remove empty params from request
      user_params.delete_if { |key, value| value.nil? }
#            user_params.each_pair do |k,v|
#                user_params[k] = v.force_encoding("UTF-8")
#            end
      #params_string  = params.to_a.collect{|key,val| key + "=#{CGI::escape(val.to_s)}" }.join("&")
      # prepare service data
      service      = lib_params[:service]
#      puts 'service=' + service.to_s
      service_hash = {"Action"         => action,
                      "AWSAccessKeyId" => aws_access_key}
      service_hash.update("Version" => api_version) if api_version
      service_hash.update(user_params)
      service_params = signed_service_params(aws_secret_key, service_hash, :get, lib_params[:server], lib_params[:service])
      #
      # use POST method if the length of the query string is too large
      # see http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/MakingRESTRequests.html
      if service_params.size > 2000
        if signature_version == '2'
          # resign the request because HTTP verb is included into signature
          service_params = signed_service_params(aws_secret_key, service_hash, :post, lib_params[:server], service)
        end
        request                 = Net::HTTP::Post.new(service)
        request.body            = service_params
        request['Content-Type'] = 'application/x-www-form-urlencoded; charset=utf-8'
      else
        request = Net::HTTP::Get.new("#{service}?#{service_params}")
      end

      #puts "\n\n --------------- QUERY REQUEST TO AWS -------------- \n\n"
      #puts "#{@params[:service]}?#{service_params}\n\n"

      # prepare output hash
      {:request  => request,
       :server   => lib_params[:server],
       :port     => lib_params[:port],
       :protocol => lib_params[:protocol]}
    end

    def get_conn(connection_name, lib_params, logger)
#            thread = lib_params[:multi_thread] ? Thread.current : Thread.main
#            thread[connection_name] ||= Rightscale::HttpConnection.new(:exception => Aws::AwsError, :logger => logger)
#            conn = thread[connection_name]
#            return conn
      http_conn = nil
      conn_mode = lib_params[:connection_mode]

      # Slice all parameters accepted by Rightscale::HttpConnection#new
      params    = lib_params.slice(
          :user_agent, :ca_file, :http_connection_retry_count, :http_connection_open_timeout,
          :http_connection_read_timeout, :http_connection_retry_delay
      )
      params.merge!(:exception => AwsError, :logger => logger)

      if conn_mode == :per_request
        http_conn = Rightscale::HttpConnection.new(params)

      elsif conn_mode == :per_thread || conn_mode == :single
        thread                  = conn_mode == :per_thread ? Thread.current : Thread.main
        thread[connection_name] ||= Rightscale::HttpConnection.new(params)
        http_conn               = thread[connection_name]
#                ret = request_info_impl(http_conn, bench, request, parser, &block)
      end
      return http_conn

    end

    def close_conn(conn_name)
      conn_mode = @params[:connection_mode]
      if conn_mode == :per_thread || conn_mode == :single
        thread = conn_mode == :per_thread ? Thread.current : Thread.main
        if !thread[conn_name].nil?
          thread[conn_name].finish
          thread[conn_name] = nil
        end
      end
    end

    def connection
      get_conn(self.class.connection_name, self.params, self.logger)
    end

    def close_connection
      close_conn(self.class.connection_name)
    end


    def request_info2(request, parser, lib_params, connection_name, logger, bench, options={}, &block) #:nodoc:
      ret       = nil
#            puts 'OPTIONS=' + options.inspect
      http_conn = get_conn(connection_name, lib_params, logger)
      begin
        # todo: this QueryTimeout retry should go into a SimpleDbErrorHandler, not here
        retry_count = 1
        count       = 0
        while count <= retry_count
          puts 'RETRYING QUERY due to QueryTimeout...' if count > 0
          begin
            ret = request_info_impl(http_conn, bench, request, parser, options, &block)
            break
          rescue Aws::AwsError => ex
            if !ex.include?(/QueryTimeout/) || count == retry_count
              raise ex
            end
          end
          count += 1
        end
      ensure
        http_conn.finish if http_conn && lib_params[:connection_mode] == :per_request
      end
      ret
    end

    # This is the latest and greatest now. Service must have connection_name defined.
    def request_info3(service_interface, request, parser, options, &block)
      request_info2(request, parser,
                    service_interface.params,
                    service_interface.class.connection_name,
                    service_interface.logger,
                    service_interface.class.bench,
                    options, &block)
    end


    # This is the direction we should head instead of writing our own parsers for everything, much simpler
    # params:
    #  - :group_tags => hash of indirection to eliminate, see: http://xml-simple.rubyforge.org/
    #  - :force_array => true for all or an array of tag names to force
    #  - :pull_out_array => an array of levels to dig into when generating return value (see rds.rb for example)
    def request_info_xml_simple(connection_name, lib_params, request, logger, params = {})

      @connection = get_conn(connection_name, lib_params, logger)
      begin
        @last_request  = request[:request]
        @last_response = nil

        response       = @connection.request(request)
        #       puts "response=" + response.body
#            benchblock.service.add!{ response = @connection.request(request) }
        # check response for errors...
        @last_response = response
        if response.is_a?(Net::HTTPSuccess)
          @error_handler     = nil
#                benchblock.xml.add! { parser.parse(response) }
#                return parser.result
          force_array        = params[:force_array] || false
          # Force_array and group_tags don't work nice together so going to force array manually
          xml_simple_options = {"KeyToSymbol"=>false, 'ForceArray' => false}
          xml_simple_options["GroupTags"] = params[:group_tags] if params[:group_tags]

#                { 'GroupTags' => { 'searchpath' => 'dir' }
#                'ForceArray' => %r(_list$)
          parsed = XmlSimple.xml_in(response.body, xml_simple_options)
          # todo: we may want to consider stripping off a couple of layers when doing this, for instance:
          # <DescribeDBInstancesResponse xmlns="http://rds.amazonaws.com/admin/2009-10-16/">
          #  <DescribeDBInstancesResult>
          #    <DBInstances>
          # <DBInstance>....
          # Strip it off and only return an array or hash of <DBInstance>'s (hash by identifier).
          # would have to be able to make the RequestId available somehow though, perhaps some special array subclass which included that?
          unless force_array.is_a? Array
            force_array = []
          end
          parsed = symbolize(parsed, force_array)
#                puts 'parsed=' + parsed.inspect
          if params[:pull_out_array]
            ret        = Aws::AwsResponseArray.new(parsed[:response_metadata])
            level_hash = parsed
            params[:pull_out_array].each do |x|
              level_hash = level_hash[x]
            end
            if level_hash.is_a? Hash # When there's only one
              ret << level_hash
            else # should be array
#                            puts 'level_hash=' + level_hash.inspect
              level_hash.each do |x|
                ret << x
              end
            end
          elsif params[:pull_out_single]
            # returns a single object
            ret        = AwsResponseObjectHash.new(parsed[:response_metadata])
            level_hash = parsed
            params[:pull_out_single].each do |x|
              level_hash = level_hash[x]
            end
            ret.merge!(level_hash)
          else
            ret = parsed
          end
          return ret

        else
          @error_handler = AWSErrorHandler.new(self, nil, :errors_list => self.class.amazon_problems) unless @error_handler
          check_result = @error_handler.check(request)
          if check_result
            @error_handler = nil
            return check_result
          end
          request_text_data = "#{request[:server]}:#{request[:port]}#{request[:request].path}"
          raise AwsError2.new(@last_response.code, @last_request_id, request_text_data, @last_response.body)
        end
      ensure
        @connection.finish if @connection && lib_params[:connection_mode] == :per_request
      end

    end

    def symbolize(hash, force_array)
      ret = {}
      hash.keys.each do |key|
        val = hash[key]
        if val.is_a? Hash
          val = symbolize(val, force_array)
          if force_array.include? key
            val = [val]
          end
        elsif val.is_a? Array
          val = val.collect { |x| symbolize(x, force_array) }
        end
        ret[key.underscore.to_sym] = val
      end
      ret
    end

    # Returns +true+ if the describe_xxx responses are being cached
    def caching?
      @params.key?(:cache) ? @params[:cache] : @@caching
    end

    # Check if the aws function response hits the cache or not.
    # If the cache hits:
    # - raises an +AwsNoChange+ exception if +do_raise+ == +:raise+.
    # - returnes parsed response from the cache if it exists or +true+ otherwise.
    # If the cache miss or the caching is off then returns +false+.
    def cache_hits?(function, response, do_raise=:raise)
      result = false
      if caching?
        function     = function.to_sym
        # get rid of requestId (this bad boy was added for API 2008-08-08+ and it is uniq for every response)
        response     = response.sub(%r{<requestId>.+?</requestId>}, '')
        response_md5 =Digest::MD5.hexdigest(response).to_s
        # check for changes
        unless @cache[function] && @cache[function][:response_md5] == response_md5
          # well, the response is new, reset cache data
          update_cache(function, {:response_md5 => response_md5,
                                  :timestamp    => Time.now,
                                  :hits         => 0,
                                  :parsed       => nil})
        else
          # aha, cache hits, update the data and throw an exception if needed
          @cache[function][:hits] += 1
          if do_raise == :raise
            raise(AwsNoChange, "Cache hit: #{function} response has not changed since "+
                "#{@cache[function][:timestamp].strftime('%Y-%m-%d %H:%M:%S')}, "+
                "hits: #{@cache[function][:hits]}.")
          else
            result = @cache[function][:parsed] || true
          end
        end
      end
      result
    end

    def update_cache(function, hash)
      (@cache[function.to_sym] ||= {}).merge!(hash) if caching?
    end

    def on_exception(options={:raise=>true, :log=>true}) # :nodoc:
      raise if $!.is_a?(AwsNoChange)
      AwsError::on_aws_exception(self, options)
    end

    # Return +true+ if this instance works in multi_thread mode and +false+ otherwise.
    def multi_thread
      @params[:multi_thread]
    end


    def request_info_impl(connection, benchblock, request, parser, options={}, &block) #:nodoc:
      @connection    = connection
      @last_request  = request[:request]
      @last_response = nil
      response       =nil
      blockexception = nil

#             puts 'OPTIONS2=' + options.inspect

      if (block != nil)
        # TRB 9/17/07 Careful - because we are passing in blocks, we get a situation where
        # an exception may get thrown in the block body (which is high-level
        # code either here or in the application) but gets caught in the
        # low-level code of HttpConnection.  The solution is not to let any
        # exception escape the block that we pass to HttpConnection::request.
        # Exceptions can originate from code directly in the block, or from user
        # code called in the other block which is passed to response.read_body.
        benchblock.service.add! do
          responsehdr = @connection.request(request) do |response|
            #########
            begin
              @last_response = response
              if response.is_a?(Net::HTTPSuccess)
                @error_handler = nil
                response.read_body(&block)
              else
                @error_handler = AWSErrorHandler.new(self, parser, :errors_list => self.class.amazon_problems) unless @error_handler
                check_result = @error_handler.check(request, options)
                if check_result
                  @error_handler = nil
                  return check_result
                end
                request_text_data = "#{request[:server]}:#{request[:port]}#{request[:request].path}"
                raise AwsError.new(@last_errors, @last_response.code, @last_request_id, request_text_data)
              end
            rescue Exception => e
              blockexception = e
            end
          end
          #########

          #OK, now we are out of the block passed to the lower level
          if (blockexception)
            raise blockexception
          end
          benchblock.xml.add! do
            parser.parse(responsehdr)
          end
          return parser.result
        end
      else
        benchblock.service.add! { response = @connection.request(request) }
        # check response for errors...
        @last_response = response
        if response.is_a?(Net::HTTPSuccess)
          @error_handler = nil
          benchblock.xml.add! { parser.parse(response) }
          return parser.result
        else
          @error_handler = AWSErrorHandler.new(self, parser, :errors_list => self.class.amazon_problems) unless @error_handler
          check_result = @error_handler.check(request, options)
          if check_result
            @error_handler = nil
            return check_result
          end
          request_text_data = "#{request[:server]}:#{request[:port]}#{request[:request].path}"
          raise AwsError.new(@last_errors, @last_response.code, @last_request_id, request_text_data)
        end
      end
    rescue
      @error_handler = nil
      raise
    end

    def request_cache_or_info(method, link, parser_class, benchblock, use_cache=true) #:nodoc:
      # We do not want to break the logic of parsing hence will use a dummy parser to process all the standard
      # steps (errors checking etc). The dummy parser does nothig - just returns back the params it received.
      # If the caching is enabled and hit then throw  AwsNoChange.
      # P.S. caching works for the whole images list only! (when the list param is blank)
      # check cache
      response, params = request_info(link, RightDummyParser.new)
      cache_hits?(method.to_sym, response.body) if use_cache
      parser = parser_class.new(:logger => @logger)
      benchblock.xml.add! { parser.parse(response, params) }
      result = block_given? ? yield(parser) : parser.result
      # update parsed data
      update_cache(method.to_sym, :parsed => result) if use_cache
      result
    end

    # Returns Amazons request ID for the latest request
    def last_request_id
      @last_response && @last_response.body.to_s[%r{<requestId>(.+?)</requestId>}] && $1
    end

    def hash_params(prefix, list) #:nodoc:
      groups = {}
      list.each_index { |i| groups.update("#{prefix}.#{i+1}"=>list[i]) } if list
      return groups
    end

  end


end

