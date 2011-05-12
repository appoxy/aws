module Aws
  class RequestData

    attr_accessor :host, :port, :protocol, :http_method, :path, :headers, :params, :body

    def initialize
      @headers = {}
    end

    def base_url
      r = "#{protocol}://#{host}"
    end

    def to_hash
      ret = {}
      self.instance_variables.each do |v|
        ret[v] = self.instance_variable_get(v)
      end
      puts 'to_hash=' + ret.inspect
      ret
    end

  end


end