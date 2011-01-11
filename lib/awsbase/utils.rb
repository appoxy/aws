module Aws

    class AwsUtils #:nodoc:
        @@digest1   = OpenSSL::Digest::Digest.new("sha1")
        @@digest256 = nil
        if OpenSSL::OPENSSL_VERSION_NUMBER > 0x00908000
            @@digest256 = OpenSSL::Digest::Digest.new("sha256") rescue nil # Some installation may not support sha256
        end

        def self.sign(aws_secret_access_key, auth_string)
            Base64.encode64(OpenSSL::HMAC.digest(@@digest1, aws_secret_access_key, auth_string)).strip
        end


        # Set a timestamp and a signature version
        def self.fix_service_params(service_hash, signature)
            service_hash["Timestamp"] ||= Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.000Z") unless service_hash["Expires"]
            service_hash["SignatureVersion"] = signature
            service_hash
        end

        # Signature Version 0
        # A deprecated guy (should work till septemper 2009)
        def self.sign_request_v0(aws_secret_access_key, service_hash)
            fix_service_params(service_hash, '0')
            string_to_sign            = "#{service_hash['Action']}#{service_hash['Timestamp'] || service_hash['Expires']}"
            service_hash['Signature'] = AwsUtils::sign(aws_secret_access_key, string_to_sign)
            service_hash.to_a.collect { |key, val| "#{amz_escape(key)}=#{amz_escape(val.to_s)}" }.join("&")
        end

        # Signature Version 1
        # Another deprecated guy (should work till septemper 2009)
        def self.sign_request_v1(aws_secret_access_key, service_hash)
            fix_service_params(service_hash, '1')
            string_to_sign            = service_hash.sort { |a, b| (a[0].to_s.downcase)<=>(b[0].to_s.downcase) }.to_s
            service_hash['Signature'] = AwsUtils::sign(aws_secret_access_key, string_to_sign)
            service_hash.to_a.collect { |key, val| "#{amz_escape(key)}=#{amz_escape(val.to_s)}" }.join("&")
        end

        # Signature Version 2
        # EC2, SQS and SDB requests must be signed by this guy.
        # See:  http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/index.html?REST_RESTAuth.html
        #       http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1928
        def self.sign_request_v2(aws_secret_access_key, service_hash, http_verb, host, uri)
            fix_service_params(service_hash, '2')
            # select a signing method (make an old openssl working with sha1)
            # make 'HmacSHA256' to be a default one
            service_hash['SignatureMethod'] = 'HmacSHA256' unless ['HmacSHA256', 'HmacSHA1'].include?(service_hash['SignatureMethod'])
            service_hash['SignatureMethod'] = 'HmacSHA1' unless @@digest256
            # select a digest
            digest           = (service_hash['SignatureMethod'] == 'HmacSHA256' ? @@digest256 : @@digest1)
            # form string to sign
            canonical_string = service_hash.keys.sort.map do |key|
                "#{amz_escape(key)}=#{amz_escape(service_hash[key])}"
            end.join('&')
            string_to_sign   = "#{http_verb.to_s.upcase}\n#{host.downcase}\n#{uri}\n#{canonical_string}"
            # sign the string
            signature        = escape_sig(Base64.encode64(OpenSSL::HMAC.digest(digest, aws_secret_access_key, string_to_sign)).strip)
            ret              = "#{canonical_string}&Signature=#{signature}"
#            puts 'full=' + ret.inspect
            ret
        end

        HEX         = [
                "%00", "%01", "%02", "%03", "%04", "%05", "%06", "%07",
                "%08", "%09", "%0A", "%0B", "%0C", "%0D", "%0E", "%0F",
                "%10", "%11", "%12", "%13", "%14", "%15", "%16", "%17",
                "%18", "%19", "%1A", "%1B", "%1C", "%1D", "%1E", "%1F",
                "%20", "%21", "%22", "%23", "%24", "%25", "%26", "%27",
                "%28", "%29", "%2A", "%2B", "%2C", "%2D", "%2E", "%2F",
                "%30", "%31", "%32", "%33", "%34", "%35", "%36", "%37",
                "%38", "%39", "%3A", "%3B", "%3C", "%3D", "%3E", "%3F",
                "%40", "%41", "%42", "%43", "%44", "%45", "%46", "%47",
                "%48", "%49", "%4A", "%4B", "%4C", "%4D", "%4E", "%4F",
                "%50", "%51", "%52", "%53", "%54", "%55", "%56", "%57",
                "%58", "%59", "%5A", "%5B", "%5C", "%5D", "%5E", "%5F",
                "%60", "%61", "%62", "%63", "%64", "%65", "%66", "%67",
                "%68", "%69", "%6A", "%6B", "%6C", "%6D", "%6E", "%6F",
                "%70", "%71", "%72", "%73", "%74", "%75", "%76", "%77",
                "%78", "%79", "%7A", "%7B", "%7C", "%7D", "%7E", "%7F",
                "%80", "%81", "%82", "%83", "%84", "%85", "%86", "%87",
                "%88", "%89", "%8A", "%8B", "%8C", "%8D", "%8E", "%8F",
                "%90", "%91", "%92", "%93", "%94", "%95", "%96", "%97",
                "%98", "%99", "%9A", "%9B", "%9C", "%9D", "%9E", "%9F",
                "%A0", "%A1", "%A2", "%A3", "%A4", "%A5", "%A6", "%A7",
                "%A8", "%A9", "%AA", "%AB", "%AC", "%AD", "%AE", "%AF",
                "%B0", "%B1", "%B2", "%B3", "%B4", "%B5", "%B6", "%B7",
                "%B8", "%B9", "%BA", "%BB", "%BC", "%BD", "%BE", "%BF",
                "%C0", "%C1", "%C2", "%C3", "%C4", "%C5", "%C6", "%C7",
                "%C8", "%C9", "%CA", "%CB", "%CC", "%CD", "%CE", "%CF",
                "%D0", "%D1", "%D2", "%D3", "%D4", "%D5", "%D6", "%D7",
                "%D8", "%D9", "%DA", "%DB", "%DC", "%DD", "%DE", "%DF",
                "%E0", "%E1", "%E2", "%E3", "%E4", "%E5", "%E6", "%E7",
                "%E8", "%E9", "%EA", "%EB", "%EC", "%ED", "%EE", "%EF",
                "%F0", "%F1", "%F2", "%F3", "%F4", "%F5", "%F6", "%F7",
                "%F8", "%F9", "%FA", "%FB", "%FC", "%FD", "%FE", "%FF"
        ]
        TO_REMEMBER = 'AZaz09 -_.!~*\'()'
        ASCII       = {} # {'A'=>65, 'Z'=>90, 'a'=>97, 'z'=>122, '0'=>48, '9'=>57, ' '=>32, '-'=>45, '_'=>95, '.'=>}
        TO_REMEMBER.each_char do |c| #unpack("c*").each do |c|
            ASCII[c] = c.unpack("c")[0]
        end
#        puts 'ascii=' + ASCII.inspect

        # Escape a string accordingly Amazon rulles
        # http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/index.html?REST_RESTAuth.html
        def self.amz_escape(param)

            param = param.to_s
#            param = param.force_encoding("UTF-8")

            e     = "x" # escape2(param.to_s)
#            puts 'ESCAPED=' + e.inspect


            #return CGI.escape(param.to_s).gsub("%7E", "~").gsub("+", "%20") # from: http://umlaut.rubyforge.org/svn/trunk/lib/aws_product_sign.rb

            #param.to_s.gsub(/([^a-zA-Z0-9._~-]+)/n) do
            #  '%' + $1.unpack('H2' * $1.size).join('%').upcase
            #end

#            puts 'e in=' + e.inspect
#            converter = Iconv.new('ASCII', 'UTF-8')
#            e = converter.iconv(e) #.unpack('U*').select{ |cp| cp < 127 }.pack('U*')
#            puts 'e out=' + e.inspect

            e2    = CGI.escape(param)
            e2    = e2.gsub("%7E", "~")
            e2    = e2.gsub("+", "%20")
            e2    = e2.gsub("*", "%2A")

#            puts 'E2=' + e2.inspect
#            puts e == e2.to_s

            e2

        end

        def self.escape2(s)
            # home grown
            ret = ""
            s.unpack("U*") do |ch|
#                puts 'ch=' + ch.inspect
                if ASCII['A'] <= ch && ch <= ASCII['Z'] # A to Z
                    ret << ch
                elsif ASCII['a'] <= ch && ch <= ASCII['z'] # a to z
                    ret << ch
                elsif ASCII['0'] <= ch && ch <= ASCII['9'] # 0 to 9
                    ret << ch
                elsif ch == ASCII[' '] # space
                    ret << "%20" # "+"
                elsif ch == ASCII['-'] || ch == ASCII['_'] || ch == ASCII['.'] || ch == ASCII['~']
                    ret << ch
                elsif ch <= 0x007f # other ascii
                    ret << HEX[ch]
                elsif ch <= 0x07FF # non-ascii
                    ret << HEX[0xc0 | (ch >> 6)]
                    ret << HEX[0x80 | (ch & 0x3F)]
                else
                    ret << HEX[0xe0 | (ch >> 12)]
                    ret << HEX[0x80 | ((ch >> 6) & 0x3F)]
                    ret << HEX[0x80 | (ch & 0x3F)]
                end

            end
            ret

        end

        def self.escape_sig(raw)
            e = CGI.escape(raw)
        end

        # From Amazon's SQS Dev Guide, a brief description of how to escape:
        # "URL encode the computed signature and other query parameters as specified in
        # RFC1738, section 2.2. In addition, because the + character is interpreted as a blank space
        # by Sun Java classes that perform URL decoding, make sure to encode the + character
        # although it is not required by RFC1738."
        # Avoid using CGI::escape to escape URIs.
        # CGI::escape will escape characters in the protocol, host, and port
        # sections of the URI.  Only target chars in the query
        # string should be escaped.
        def self.URLencode(raw)
            e = URI.escape(raw)
            e.gsub(/\+/, "%2b")
        end


        def self.allow_only(allowed_keys, params)
            bogus_args = []
            params.keys.each { |p| bogus_args.push(p) unless allowed_keys.include?(p) }
            raise AwsError.new("The following arguments were given but are not legal for the function call #{caller_method}: #{bogus_args.inspect}") if bogus_args.length > 0
        end

        def self.mandatory_arguments(required_args, params)
            rargs = required_args.dup
            params.keys.each { |p| rargs.delete(p) }
            raise AwsError.new("The following mandatory arguments were not provided to #{caller_method}: #{rargs.inspect}") if rargs.length > 0
        end

        def self.caller_method
            caller[1]=~/`(.*?)'/
            $1
        end

    end
end