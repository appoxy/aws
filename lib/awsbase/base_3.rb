module Aws

  # This module will hold the new base connection handling code, Should replace a lot of the stuff that's in awsbase.
  module Base3


    def aws_execute(request_data, options={})
      if @params[:executor]
        EventMachine.run do
          puts 'base_url=' + request_data.base_url
          req = EventMachine::HttpRequest.new(request_data.base_url)

          opts = {:timeout => options[:timeout], :head => options[:headers]} #, :ssl => true

          if request_data.http_method == :post
            http = req.post opts.merge(:path=>request_data.path, :body=>request_data.body)
          else
            http = req.get opts.merge(:path=>request_data.path, :query=>request_data.body)
          end

          http.errback {
            puts 'Uh oh'
            p http.response_header.status
            p http.response_header
            p http.response
            EM.stop
          }
          http.callback {
            puts 'success callback'
            p options
            p http.response_header.status
            p http.response_header
            p http.response
            if options[:parser]
              parse_response(http.response, options[:parser])
            end

            EventMachine.stop
          }
        end
      else
        # use straight up http
        conn = new_faraday_connection(request_data.host)
        if request_data.http_method == :post
          faraday_response = conn.post request_data.path, request_data.body, request_data.headers.merge('Content-Type' => 'application/x-www-form-urlencoded; charset=utf-8')
        else
          faraday_response = conn.get "#{request_data.path}?#{request_data.body}", request_data.headers
        end
        puts 'faraday_response = ' + faraday_response.inspect
        if options[:parser]
          return parse_response(faraday_response.body, options[:parser])
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