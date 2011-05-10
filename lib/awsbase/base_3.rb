module Aws

  # This module will hold the new base connection handling code, Should replace a lot of the stuff that's in awsbase.
  module Base3


    def aws_execute(request_data, options={})
      if @params[:executor]
        require 'em-http'
        require 'fiber'
        EventMachine.run do
          Fiber.new {
            puts 'base_url=' + request_data.base_url
            f = Fiber.current
            req = EventMachine::HttpRequest.new(request_data.base_url)

            opts = {:timeout => options[:timeout], :head => options[:headers]} #, :ssl => true

            if request_data.http_method == :post
              http = req.post opts.merge(:path=>request_data.path, :body=>request_data.body)
            else
              http = req.get opts.merge(:path=>request_data.path, :query=>request_data.body)
            end
            if http.error.empty?
              http.errback {
                puts 'Uh oh'
                p http.response_header.status
                p http.response_header
                p http.response
                EM.stop
                f.resume(http) if f.alive?
              }
              http.callback {
                puts 'success callback'
                p options
                p http.response_header.status
                p http.response_header
                http.response
                if options[:parser]
                  http = parse_response(http.response, options[:parser])
                end
                f.resume(http) if f.alive?
              }
              Fiber.yield
            end
            @result = http
            EventMachine.stop
          }.resume

        end
        @result
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
        @last_response = faraday_response
        parser = options[:parser]
        if parser
          if response_2xx(faraday_response.status) #  response.is_a?(Net::HTTPSuccess)
            @error_handler = nil
            return parse_response(faraday_response, parser)
          else
            @error_handler = AWSErrorHandler.new(self, parser, :errors_list => self.class.amazon_problems) unless @error_handler
            check_result = @error_handler.check({:server=>request_data.host,:port=>request_data.port,:request=>request_data,:protocol=>request_data.http_method}, options)
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

    def parse_response(body, parser)
      puts 'parsing'
      parser.parse(body)
      r = parser.result
      puts 'r=' + r.inspect
      r
    end


  end

end