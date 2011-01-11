module Aws

# Exception class to signal any Amazon errors. All errors occuring during calls to Amazon's
# web services raise this type of error.
# Attribute inherited by RuntimeError:
#  message    - the text of the error, generally as returned by AWS in its XML response.
  class AwsError < RuntimeError

    # either an array of errors where each item is itself an array of [code, message]),
    # or an error string if the error was raised manually, as in <tt>AwsError.new('err_text')</tt>
    attr_reader :errors

    # Request id (if exists)
    attr_reader :request_id

    # Response HTTP error code
    attr_reader :http_code

    # Raw request text data to AWS
    attr_reader :request_data

    attr_reader :response

    def initialize(errors=nil, http_code=nil, request_id=nil, request_data=nil, response=nil)
      @errors       = errors
      @request_id   = request_id
      @http_code    = http_code
      @request_data = request_data
      @response     = response
      msg           = @errors.is_a?(Array) ? @errors.map { |code, msg| "#{code}: #{msg}" }.join("; ") : @errors.to_s
      msg += "\nREQUEST=#{@request_data} " unless @request_data.nil?
      msg += "\nREQUEST ID=#{@request_id} " unless @request_id.nil?
      super(msg)
    end

    # Does any of the error messages include the regexp +pattern+?
    # Used to determine whether to retry request.
    def include?(pattern)
      if @errors.is_a?(Array)
        @errors.each { |code, msg| return true if code =~ pattern }
      else
        return true if @errors_str =~ pattern
      end
      false
    end

    # Generic handler for AwsErrors. +aws+ is the Aws::S3, Aws::EC2, or Aws::SQS
    # object that caused the exception (it must provide last_request and last_response). Supported
    # boolean options are:
    # * <tt>:log</tt> print a message into the log using aws.logger to access the Logger
    # * <tt>:puts</tt> do a "puts" of the error
    # * <tt>:raise</tt> re-raise the error after logging
    def self.on_aws_exception(aws, options={:raise=>true, :log=>true})
      # Only log & notify if not user error
      if !options[:raise] || system_error?($!)
        error_text = "#{$!.inspect}\n#{$@}.join('\n')}"
        puts error_text if options[:puts]
        # Log the error
        if options[:log]
          request   = aws.last_request ? aws.last_request.path : '-none-'
          response  = aws.last_response ? "#{aws.last_response.code} -- #{aws.last_response.message} -- #{aws.last_response.body}" : '-none-'
          @response = response
          aws.logger.error error_text
          aws.logger.error "Request was:  #{request}"
          aws.logger.error "Response was: #{response}"
        end
      end
      raise if options[:raise] # re-raise an exception
      return nil
    end

    # True if e is an AWS system error, i.e. something that is for sure not the caller's fault.
    # Used to force logging.
    def self.system_error?(e)
      !e.is_a?(self) || e.message =~ /InternalError|InsufficientInstanceCapacity|Unavailable/
    end

  end

# Simplified version
  class AwsError2 < RuntimeError
    # Request id (if exists)
    attr_reader :request_id

    # Response HTTP error code
    attr_reader :http_code

    # Raw request text data to AWS
    attr_reader :request_data

    attr_reader :response

    attr_reader :errors

    def initialize(http_code=nil, request_id=nil, request_data=nil, response=nil)

      @request_id   = request_id
      @http_code    = http_code
      @request_data = request_data
      @response     = response
#            puts '@response=' + @response.inspect

      if @response
        ref = XmlSimple.xml_in(@response, {"ForceArray"=>false})
#                puts "refxml=" + ref.inspect
        msg = "#{ref['Error']['Code']}: #{ref['Error']['Message']}"
      else
        msg = "#{@http_code}: REQUEST(#{@request_data})"
      end
      msg += "\nREQUEST ID=#{@request_id} " unless @request_id.nil?
      super(msg)
    end


  end


  class AWSErrorHandler
    # 0-100 (%)
    DEFAULT_CLOSE_ON_4XX_PROBABILITY = 10

    @@reiteration_start_delay        = 0.2

    def self.reiteration_start_delay
      @@reiteration_start_delay
    end

    def self.reiteration_start_delay=(reiteration_start_delay)
      @@reiteration_start_delay = reiteration_start_delay
    end

    @@reiteration_time = 5

    def self.reiteration_time
      @@reiteration_time
    end

    def self.reiteration_time=(reiteration_time)
      @@reiteration_time = reiteration_time
    end

    @@close_on_error = true

    def self.close_on_error
      @@close_on_error
    end

    def self.close_on_error=(close_on_error)
      @@close_on_error = close_on_error
    end

    @@close_on_4xx_probability = DEFAULT_CLOSE_ON_4XX_PROBABILITY

    def self.close_on_4xx_probability
      @@close_on_4xx_probability
    end

    def self.close_on_4xx_probability=(close_on_4xx_probability)
      @@close_on_4xx_probability = close_on_4xx_probability
    end

    # params:
    #  :reiteration_time
    #  :errors_list
    #  :close_on_error           = true | false
    #  :close_on_4xx_probability = 1-100
    def initialize(aws, parser, params={}) #:nodoc:
      @aws                      = aws # Link to RightEc2 | RightSqs | RightS3 instance
      @parser                   = parser # parser to parse Amazon response
      @started_at               = Time.now
      @stop_at                  = @started_at + (params[:reiteration_time] || @@reiteration_time)
      @errors_list              = params[:errors_list] || []
      @reiteration_delay        = @@reiteration_start_delay
      @retries                  = 0
      # close current HTTP(S) connection on 5xx, errors from list and 4xx errors
      @close_on_error           = params[:close_on_error].nil? ? @@close_on_error : params[:close_on_error]
      @close_on_4xx_probability = params[:close_on_4xx_probability] || @@close_on_4xx_probability
    end

    # Returns false if
    def check(request, options={}) #:nodoc:
      result            = false
      error_found       = false
      redirect_detected = false
      error_match       = nil
      last_errors_text  = ''
      response          = @aws.last_response
      # log error
      request_text_data = "#{request[:server]}:#{request[:port]}#{request[:request].path}"
      # is this a redirect?
      # yes!
      if response.is_a?(Net::HTTPRedirection)
        redirect_detected = true
      else
        # no, it's an error ...
        @aws.logger.warn("##### #{@aws.class.name} returned an error: #{response.code} #{response.message}\n#{response.body} #####")
        @aws.logger.warn("##### #{@aws.class.name} request: #{request_text_data} ####")
      end
      # Check response body: if it is an Amazon XML document or not:
      if redirect_detected || (response.body && response.body[/<\?xml/]) # ... it is a xml document
        @aws.class.bench_xml.add! do
          error_parser = RightErrorResponseParser.new
          error_parser.parse(response)
          @aws.last_errors     = error_parser.errors
          @aws.last_request_id = error_parser.requestID
          last_errors_text     = @aws.last_errors.flatten.join("\n")
          # on redirect :
          if redirect_detected
            location = response['location']
            # ... log information and ...
            @aws.logger.info("##### #{@aws.class.name} redirect requested: #{response.code} #{response.message} #####")
            @aws.logger.info("##### New location: #{location} #####")
            # ... fix the connection data
            request[:server]   = URI.parse(location).host
            request[:protocol] = URI.parse(location).scheme
            request[:port]     = URI.parse(location).port
          end
        end
      else # ... it is not a xml document(probably just a html page?)
        @aws.last_errors     = [[response.code, "#{response.message} (#{request_text_data})"]]
        @aws.last_request_id = '-undefined-'
        last_errors_text     = response.message
      end
      # now - check the error
      unless redirect_detected
        @errors_list.each do |error_to_find|
          if last_errors_text[/#{error_to_find}/i]
            error_found = true
            error_match = error_to_find
            @aws.logger.warn("##### Retry is needed, error pattern match: #{error_to_find} #####")
            break
          end
        end
      end
      # check the time has gone from the first error come
      if redirect_detected || error_found
        # Close the connection to the server and recreate a new one.
        # It may have a chance that one server is a semi-down and reconnection
        # will help us to connect to the other server
        if !redirect_detected && @close_on_error
          @aws.connection.finish "#{self.class.name}: error match to pattern '#{error_match}'"
        end
# puts 'OPTIONS3=' + options.inspect
        if options[:retries].nil? || @retries < options[:retries]
          if (Time.now < @stop_at)
            @retries += 1
            unless redirect_detected
              @aws.logger.warn("##### Retry ##{@retries} is being performed. Sleeping for #{@reiteration_delay} sec. Whole time: #{Time.now-@started_at} sec ####")
              sleep @reiteration_delay
              @reiteration_delay *= 2

              # Always make sure that the fp is set to point to the beginning(?)
              # of the File/IO. TODO: it assumes that offset is 0, which is bad.
              if (request[:request].body_stream && request[:request].body_stream.respond_to?(:pos))
                begin
                  request[:request].body_stream.pos = 0
                rescue Exception => e
                  @logger.warn("Retry may fail due to unable to reset the file pointer" +
                                   " -- #{self.class.name} : #{e.inspect}")
                end
              end
            else
              @aws.logger.info("##### Retry ##{@retries} is being performed due to a redirect.  ####")
            end
            result = @aws.request_info(request, @parser, options)
          else
            @aws.logger.warn("##### Ooops, time is over... ####")
          end
        else
          @aws.logger.info("##### Stopped retrying because retries=#{@retries} and max=#{options[:retries]}  ####")
        end
        # aha, this is unhandled error:
      elsif @close_on_error
        # Is this a 5xx error ?
        if @aws.last_response.code.to_s[/^5\d\d$/]
          @aws.connection.finish "#{self.class.name}: code: #{@aws.last_response.code}: '#{@aws.last_response.message}'"
          # Is this a 4xx error ?
        elsif @aws.last_response.code.to_s[/^4\d\d$/] && @close_on_4xx_probability > rand(100)
          @aws.connection.finish "#{self.class.name}: code: #{@aws.last_response.code}: '#{@aws.last_response.message}', " +
                                     "probability: #{@close_on_4xx_probability}%"
        end
      end
      result
    end

  end

end