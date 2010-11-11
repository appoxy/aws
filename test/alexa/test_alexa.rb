require File.dirname(__FILE__) + '/test_helper.rb'
require 'pp'
require File.dirname(__FILE__) + '/../test_credentials.rb'

require 'ruby-debug'
Debugger.start

# Tests the Alexa AWS implementation
# Note this is very preliminary code. The code just spits back hashes
# and it has no concept of types just yet. The parser can 
# be overriden on the calls if you need stronger types and must 
# have something right away.
class TestAlexa < Test::Unit::TestCase

		def setup
        TestCredentials.get_credentials
        @alexa   = Aws::Alexa.new(TestCredentials.aws_access_key_id,
                              TestCredentials.aws_secret_access_key)
		end

		# Quick rank request
		def test_rank
		return
			TestCredentials.get_credentials
			rank = @alexa.alexa_rank("http://www.youtube.com")
			assert ! rank.empty?
			assert ! rank[:rank][:text].blank?
			assert rank[:rank][:text].to_i > 0
			assert ! rank[:data_url][:text].blank?
		end

		def test_alexa_urlinfo
			TestCredentials.get_credentials
			result = @alexa.alexa_url_info("http://www.yahoo.com")
			assert result[:url_info_response][:response][:url_info_result][:alexa][:contact_info][:company_stock_ticker][:text] == "YHOO"
		end

		def test_alexa_category_browse
			TestCredentials.get_credentials
			category_browse = @alexa.alexa_category_browse("Top/Computers/Software/Operating_Systems")
			assert ! category_browse.empty?
			assert ! category_browse[:category_browse_response][:response][:category_browse_result][:alexa][:category_browse][:categories][:category].first[:path][:text].blank?
			
		end

		def test_alexa_category_listings
			TestCredentials.get_credentials
			category_browse = @alexa.alexa_category_listings("Top/Computers/Software/Operating_Systems")
			assert ! category_browse.empty?
			assert category_browse[:category_listings_response][:response][:category_listings_result][:alexa][:category_listings][:listings][:listing].length > 0
		end

end
