module Aws
class Alexa
  include AwsBaseInterface
	DEFAULT_HOST = "awis.amazonaws.com"
	DEFAULT_PATH = "/"
  API_VERSION = "2005-07-11"
  DEFAULT_PROTOCOL = 'http'
  DEFAULT_PORT     = 80

  VALID_URLINFO_RESPONSE_GROUPS = [
    :related_links,
    :categories,
    :rank,
    :rank_by_country,
    :rank_by_city,
    :usage_stats,
    :contact_info,
    :adult_content,
    :speed,
    :language,
    :keywords,
    :owned_domains,
    :links_in_count,
    :site_data
  ]
    # TODO - the docs mentions :popups on the meta groups, but it's not on the response group. Oversight? Check to see if that kind of info is being passed

	VALID_CATEGORY_BROWSE_RESPONSE_GROUPS = [ :categories, 
			:related_categories, 
			:language_categories, 
			:letter_bars
	]

  META_GROUPS = {
    :related=>[:related_links, :categories],
    :traffic_data=>[:rank, :usage_stats],
    :content_data=>[:site_data, :adult_content, :popups, :speed, :language]
  }
  @@bench = AwsBenchmarkingBlock.new
  def self.bench_xml
    @@bench.xml
  end
  def self.bench_ec2
    @@bench.service
  end

	@@api = ENV['ALEXA_API_VERSION'] || API_VERSION
  def initialize(aws_access_key_id=nil, aws_secret_access_key=nil, params={})
    init({ :name             => 'ALEXA',
           :default_host     => ENV['ALEXA_URL'] ? URI.parse(ENV['ALEXA_URL']).host   : DEFAULT_HOST,
           :default_port     => ENV['ALEXA_URL'] ? URI.parse(ENV['ALEXA_URL']).port   : DEFAULT_PORT,
           :default_service  => ENV['ALEXA_URL'] ? URI.parse(ENV['ALEXA_URL']).path   : DEFAULT_PATH,
           :default_protocol => ENV['ALEXA_URL'] ? URI.parse(ENV['ALEXA_URL']).scheme : DEFAULT_PROTOCOL,
          :api_version => API_VERSION },
         aws_access_key_id    || ENV['AWS_ACCESS_KEY_ID'] ,
         aws_secret_access_key|| ENV['AWS_SECRET_ACCESS_KEY'],
         params)
    # EC2 doesn't really define any transient errors to retry, and in fact,
    # when they return a 503 it is usually for 'request limit exceeded' which
    # we most certainly should not retry.  So let's pare down the list of
    # retryable errors to InternalError only (see AwsBase for the default
    # list)
    amazon_problems = ['InternalError']
  end

  def generate_request(action, params={}) #:nodoc:
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
      request = Net::HTTP::Post.new(@params[:service])
      request.body = service_params
      request['Content-Type'] = 'application/x-www-form-urlencoded'
    else
      request        = Net::HTTP::Get.new("#{@params[:service]}?#{service_params}")
    end
      # prepare output hash
    { :request  => request,
      :server   => @params[:server],
      :port     => @params[:port],
      :protocol => @params[:protocol] }
  end

  def request_info(request, parser)  #:nodoc:
    thread = @params[:multi_thread] ? Thread.current : Thread.main
    thread[:ec2_connection] ||= Rightscale::HttpConnection.new(:exception => AwsError, :logger => @logger)
    request_info_impl(thread[:ec2_connection], @@bench, request, parser)
  end

	# Quickly return the alexa URL info, (rank only)
	#
	# Example:
	# 	alexa_rank("http://www.yahoo.com")[:rank][:text]  # 4
	def alexa_rank(url, params={}, cache_for = nil)
		result =  alexa_url_info(url, {:response_groups=>:rank})
		return result[:url_info_response][:response][:url_info_result][:alexa][:traffic_data]
	end

	# Retrieves the Alexa URL info for a URL.
	# By default it returns every response group. 
	# Override response_groups to set your own.
	#
	# Example:
	#  alexa_url_info("http://www.google.com")[:url_info_response]..
	def alexa_url_info(url, opts={}, cache_for=nil, parser = QAlexaUrlInfoParser)
		options = {:response_groups=>VALID_URLINFO_RESPONSE_GROUPS}.merge(opts)
		request_hash = {}
		request_hash['Url'] = url
		request_hash['ResponseGroup'] = response_groups_to_param(options[:response_groups])
		params.each do |key, val|
			request_hash.merge! hash_params(key, (val.is_a?(Array) ? val : [val]))
		end
		link = generate_request('UrlInfo', request_hash)
		request_cache_or_info(cache_for, link, parser, @@bench, cache_for)
	rescue Exception
		on_exception
	end

	# Returns a list of subcategories inside a category
	#
  def alexa_category_browse(path, opts={}, cache_for=nil, parser = QAlexaUrlInfoParser)
		options = {:response_groups=>VALID_CATEGORY_BROWSE_RESPONSE_GROUPS}.merge(opts)
		request_hash = {}
		request_hash['Path'] = path
		request_hash['ResponseGroup'] = response_groups_to_param(options[:response_groups])
		params.each do |key, val|
		request_hash.merge! hash_params(key, (val.is_a?(Array) ? val : [val]))
		end
		link = generate_request('CategoryBrowse', request_hash)
		request_cache_or_info(cache_for, link, parser, @@bench, cache_for)
	rescue Exception
		on_exception
  end

	# Returns a list of category listings
  def alexa_category_listings(path, cache_for=nil, parser = QAlexaUrlInfoParser)
		request_hash = {}
		request_hash['Path'] = path
		request_hash['ResponseGroup'] = "Listings"
		params.each do |key, val|
		request_hash.merge! hash_params(key, (val.is_a?(Array) ? val : [val]))
		end
		link = generate_request('CategoryListings', request_hash)
		request_cache_or_info(cache_for, link, parser, @@bench, cache_for)
	rescue Exception
		on_exception
  end

  def alexa_sites_linking_in(path, cache_for, parser = QAlexaUrlInfoParser)
		request_hash = {}
		request_hash['Path'] = path
		request_hash['ResponseGroup'] = "SitesLinkingIn"
		params.each do |key, val|
		request_hash.merge! hash_params(key, (val.is_a?(Array) ? val : [val]))
		end
		link = generate_request('CategoryListings', request_hash)
		request_cache_or_info(cache_for, link, parser, @@bench, cache_for)
	rescue Exception
		on_exception
  end

  def alexa_traffic_history
    throw ArgumentError.new("Not Implemented. Sorry!")
  end

	private

		def response_groups_to_param(groups)
			actual_groups = groups.is_a?(Array) ? groups : [groups]
			actual_groups.collect{|g| g.to_s.camelize }.join(",")
		end

end

	class QAlexaElementHash < Hash
		attr_accessor :finalized
		def last
			self
		end
		def to_s
			return has_key?(:text) ? self[:text] : super.to_s
		end
	end

	class QAlexaUrlInfoParser < AwsParser

		def initialize(args)
			super(args)
			@result = {}
		end

		def tagstart(name, attr)
			item = current_item(name)
			_attr = attr.dup
			_attr.delete("xmlns:aws")
			item.merge!(_attr)
		end

		def tagend(name)
			element = current_item(name)
			element[:text] = @text.strip
			element.finalized = true
		end

		def current_item(name)
			outer = @result
			inner = nil
			path_array = @xmlpath.split('/')
			path_array << name
			path_array.collect{|s| s.sub('aws:','')}.each{|_xpath_element|
				name_sym = symbol_for(_xpath_element)
				inner = outer[name_sym] || QAlexaElementHash.new
				inner = inner.last # Sometimes we may get an array.
				if inner.finalized
					old_inner = inner
					inner = QAlexaElementHash.new
					outer[name_sym] = [old_inner, inner]
				end
				outer[name_sym] = inner if ! outer.has_key?(name_sym)
				outer = inner
			}
			return inner.nil? ? outer : inner
		end

		def symbol_for(name)
			sym_name = name.sub('aws:','').underscore.to_sym
		end

	end

end
