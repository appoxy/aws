module Aws
  class RequestData

    attr_accessor :host, :port, :protocol, :http_method, :path, :headers, :params, :body

    def initialize
      @headers = {}
    end

    def base_url
      r = "#{protocol}://#{host}"
    end

  end


end