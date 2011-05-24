module Aws

  # This module will hold the new base connection handling code, Should replace a lot of the stuff that's in awsbase.
  module Base3


    def aws_execute(request_data, options={})
      if @params[:executor]
        executor = @params[:executor]
        puts 'using executor ' + executor.inspect

        params_to_send = {:timeout => options[:timeout], :headers => options[:headers]||request_data.headers}
        params_to_send[:base_url] = request_data.base_url
        params_to_send[:path] = request_data.path
        params_to_send[:http_method] = request_data.http_method
        if request_data.http_method == :post || request_data.http_method == :put
          params_to_send[:body] = request_data.body
        else
          params_to_send[:query] = request_data.body
        end

        f = executor.http_request(params_to_send) do |response|
          if options[:parser]
            puts 'parsing=' + response.body
            res = parse_response(response, options[:parser])
          else
            raise "no parser yo"
          end
        end
        puts 'f=' + f.inspect
        return f
#      elsif @params[:eventmachine]
#        # This isn't actually that useful because you can't get the response, but is here for testing
#        require 'em-http'
#        require 'fiber'
#        EventMachine.run do
#          #Fiber.new {
#            puts 'base_url=' + request_data.base_url
#            f = Fiber.current
#            req = EventMachine::HttpRequest.new(request_data.base_url)
#
#            opts = {:timeout => options[:timeout], :head => options[:headers]} #, :ssl => true
#
#            if request_data.http_method == :post
#              http = req.post opts.merge(:path=>request_data.path, :body=>request_data.body)
#            else
#              http = req.get opts.merge(:path=>request_data.path, :query=>request_data.body)
#            end
#            if http.error.empty?
#              http.errback {
#                puts 'Uh oh'
#                p http.response_header.status
#                p http.response_header
#                p http.response
#                EM.stop
#                f.resume(http) if f.alive?
#              }
#              http.callback {
#                puts 'success callback'
#                p options
#                p http.response_header.status
#                p http.response_header
#                http.response
#                if options[:parser]
#                  http = parse_response(http.response, options[:parser])
#                end
#                f.resume(http) if f.alive?
#              }
#              Fiber.yield
#            end
#            @result = http
#            EventMachine.stop
#          #}.resume
#
#        end
#        @result
      else
        # use straight up http
        conn = new_faraday_connection(request_data.host)
        if request_data.http_method == :post
          faraday_response = conn.post request_data.path, request_data.body, request_data.headers.merge('Content-Type' => 'application/x-www-form-urlencoded; charset=utf-8')
        elsif request_data.http_method == :put
          faraday_response = conn.put request_data.path, request_data.body, request_data.headers
        elsif request_data.http_method == :head
          faraday_response = conn.head request_data.path, request_data.headers
        elsif  request_data.http_method == :delete
          faraday_response = conn.delete request_data.path, request_data.headers
        else
          faraday_response = conn.get "#{request_data.path}?#{request_data.body}", request_data.headers
        end
        puts 'faraday_response = ' + faraday_response.inspect
        p faraday_response.headers
        p faraday_response.body
        @last_response = faraday_response
        parser = options[:parser]
        if parser
          if response_2xx(faraday_response.status) #  response.is_a?(Net::HTTPSuccess)
            @error_handler = nil
            return parse_response(faraday_response, parser)
          else
            @error_handler = AWSErrorHandler.new(self, parser, :errors_list => self.class.amazon_problems) unless @error_handler
            check_result = @error_handler.check({:server=>request_data.host, :port=>request_data.port, :request=>request_data, :protocol=>request_data.http_method}, options)
            if check_result
              @error_handler = nil
              return check_result
            end
            request_text_data = "#{request_data.host}:#{request_data.port}#{request_data.path}"
            raise AwsError.new(@last_errors, @last_response.status, @last_request_id, request_text_data)
          end
        end
      end

    end

    def parse_response(response, parser)
      puts 'parsing=' + response.body.to_s
      parser.parse(response)
      r = parser.result
      puts 'r=' + r.inspect
      r
    end


  end

end