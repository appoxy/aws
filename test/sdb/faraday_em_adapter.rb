module Faraday
  class Adapter
    class EventMachine < Faraday::Adapter
      dependency do
        require 'eventmachine'
        require 'em-http'
      end

      def call(env)
        super


        ret = Faraday::AsyncResponse.new(@app, env)

        http = ::EventMachine::HttpRequest.new(env[:url])
        method = env[:method].to_s.downcase
        if method == 'post'
          http = http.post :body => env[:body]
        else
          http = http.get
        end
        puts 'http=' + http.inspect

        ret.em_request = http

        http.errback {
          ret.call_errback
        }
        http.callback {
          p http.response_header.status
          p http.response_header
          p http.response
          ret.call_callback(http)
          env.update :status => http.response_header.status, :body=>http.response
          @app.call env
        }

        ret

      rescue Errno::ECONNREFUSED
        raise Error::ConnectionFailed, $!
      end
    end

    class EventMachineFutureAdapter < Faraday::Adapter
      dependency do
        require 'eventmachine'
        require 'em-http'
        require 'concur'
      end

      def call(env)
        super

#        uri = URI::parse(env[:url].to_s)
#        port = env[:ssl] || 80


#        conn = EM::Protocols::HttpClient2.connect(:host=>uri.host, :port=>80, :ssl=>env[:ssl])


        http = ::EventMachine::HttpRequest.new(env[:url])
        method = env[:method].to_s.downcase
        if method == 'post'
          http = http.post :body => env[:body]
        else
          http = http.get
        end
        puts 'http=' + http.inspect

        resp = Faraday::AsyncResponse.new(@app, env)
        resp.em_request = http

        ret = Concur::EventMachineFutureCallback.new(http) do |http|
          puts 'futurecallback called ' + http.inspect
          p http.response_header.status
          p http.response_header
          p http.response
          resp.call_callback(http)
          env.update :status => http.response_header.status, :body=>http.response
          @app.call env
        end
        ret

#        http


      rescue Errno::ECONNREFUSED
        raise Error::ConnectionFailed, $!
      end
    end

  end

  class Response
    def async?
      false
    end
  end

  class AsyncResponse < Faraday::Response
    attr_accessor :em_request, :app, :env, :errblk, :callblk

    def initialize(app, env)
      @app = app
      @env = env
    end

    def async?
      true
    end

    def errback &blk
      @errblk = blk
    end

    def callback &blk
      @callblk = blk
    end

    def call_callback(response)
      puts 'call_callback=' + response.inspect
      return unless callblk
      callblk.call(ResponseWrapper.new(response))
    end

    def call_errback(response)
      return unless errblk
      errblk.call(ResponseWrapper.new(response))
    end
  end


  class ResponseWrapper
    attr_accessor :http

    def initialize(http)
      @http = http
    end

    def body
      http.response
    end

    def status
      http.response_header.status
    end

    def headers
      http.response_header
    end

  end
end
