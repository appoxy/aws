module Aws

#-----------------------------------------------------------------

  class RightSaxParserCallback #:nodoc:
    def self.include_callback
      include XML::SaxParser::Callbacks
    end

    def initialize(right_aws_parser)
      @right_aws_parser = right_aws_parser
    end

    def on_start_element(name, attr_hash)
      @right_aws_parser.tag_start(name, attr_hash)
    end

    def on_characters(chars)
      @right_aws_parser.text(chars)
    end

    def on_end_element(name)
      @right_aws_parser.tag_end(name)
    end

    def on_start_document;
    end

    def on_comment(msg)
      ;
    end

    def on_processing_instruction(target, data)
      ;
    end

    def on_cdata_block(cdata)
      ;
    end

    def on_end_document;
    end
  end

  class AwsParser #:nodoc:
    # default parsing library
    DEFAULT_XML_LIBRARY  = 'rexml'
    # a list of supported parsers
    @@supported_xml_libs = [DEFAULT_XML_LIBRARY, 'libxml']

    @@xml_lib            = DEFAULT_XML_LIBRARY # xml library name: 'rexml' | 'libxml'
    def self.xml_lib
      @@xml_lib
    end

    def self.xml_lib=(new_lib_name)
      @@xml_lib = new_lib_name
    end

    attr_accessor :result
    attr_reader :xmlpath
    attr_accessor :xml_lib

    def initialize(params={})
      @xmlpath = ''
      @result  = false
      @text    = ''
      @xml_lib = params[:xml_lib] || @@xml_lib
      @logger  = params[:logger]
      reset
    end

    def tag_start(name, attributes)
      @text = ''
      tagstart(name, attributes)
      @xmlpath += @xmlpath.empty? ? name : "/#{name}"
    end

    def tag_end(name)
      if @xmlpath =~ /^(.*?)\/?#{name}$/
        @xmlpath = $1
      end
      tagend(name)
    end

    def text(text)
      @text += text
      tagtext(text)
    end

    # Parser method.
    # Params:
    #   xml_text         - xml message text(String) or Net:HTTPxxx instance (response)
    #   params[:xml_lib] - library name: 'rexml' | 'libxml'
    def parse(xml_text, params={})
      # Get response body
      unless xml_text.is_a?(String)
        xml_text = xml_text.body.respond_to?(:force_encoding) ? xml_text.body.force_encoding("UTF-8") : xml_text.body
      end

      @xml_lib = params[:xml_lib] || @xml_lib
      # check that we had no problems with this library otherwise use default
      @xml_lib = DEFAULT_XML_LIBRARY unless @@supported_xml_libs.include?(@xml_lib)
      # load xml library
      if @xml_lib=='libxml' && !defined?(XML::SaxParser)
        begin
          require 'xml/libxml'
          # is it new ? - Setup SaxParserCallback
          if XML::Parser::VERSION >= '0.5.1.0'
            RightSaxParserCallback.include_callback
          end
        rescue LoadError => e
          @@supported_xml_libs.delete(@xml_lib)
          @xml_lib = DEFAULT_XML_LIBRARY
          if @logger
            @logger.error e.inspect
            @logger.error e.backtrace
            @logger.info "Can not load 'libxml' library. '#{DEFAULT_XML_LIBRARY}' is used for parsing."
          end
        end
      end
      # Parse the xml text
      case @xml_lib
        when 'libxml'
          xml = XML::SaxParser.string(xml_text)
          # check libxml-ruby version
          if XML::Parser::VERSION >= '0.5.1.0'
            xml.callbacks = RightSaxParserCallback.new(self)
          else
            xml.on_start_element { |name, attr_hash| self.tag_start(name, attr_hash) }
            xml.on_characters { |text| self.text(text) }
            xml.on_end_element { |name| self.tag_end(name) }
          end
          xml.parse
        else
          REXML::Document.parse_stream(xml_text, self)
      end
    end

    # Parser must have a lots of methods
    # (see /usr/lib/ruby/1.8/rexml/parsers/streamparser.rb)
    # We dont need most of them in AwsParser and method_missing helps us
    # to skip their definition
    def method_missing(method, *params)
      # if the method is one of known - just skip it ...
      return if [:comment, :attlistdecl, :notationdecl, :elementdecl,
                 :entitydecl, :cdata, :xmldecl, :attlistdecl, :instruction,
                 :doctype].include?(method)
      # ... else - call super to raise an exception
      super(method, params)
    end

    # the functions to be overriden by children (if nessesery)
    def reset;
    end

    def tagstart(name, attributes)
      ;
    end

    def tagend(name)
      ;
    end

    def tagtext(text)
      ;
    end
  end

#-----------------------------------------------------------------
#      PARSERS: Errors
#-----------------------------------------------------------------

#<Error>
#  <Code>TemporaryRedirect</Code>
#  <Message>Please re-send this request to the specified temporary endpoint. Continue to use the original request endpoint for future requests.</Message>
#  <RequestId>FD8D5026D1C5ABA3</RequestId>
#  <Endpoint>bucket-for-k.s3-external-3.amazonaws.com</Endpoint>
#  <HostId>ItJy8xPFPli1fq/JR3DzQd3iDvFCRqi1LTRmunEdM1Uf6ZtW2r2kfGPWhRE1vtaU</HostId>
#  <Bucket>bucket-for-k</Bucket>
#</Error>

  class RightErrorResponseParser < AwsParser #:nodoc:
    attr_accessor :errors # array of hashes: error/message
    attr_accessor :requestID
#    attr_accessor :endpoint, :host_id, :bucket
    def parse(response)
      super
    end

    def tagend(name)
      case name
        when 'RequestID';
          @requestID = @text
        when 'Code';
          @code = @text
        when 'Message';
          @message = @text
#       when 'Endpoint'  ; @endpoint  = @text
#       when 'HostId'    ; @host_id   = @text
#       when 'Bucket'    ; @bucket    = @text
        when 'Error';
          @errors << [@code, @message]
      end
    end

    def reset
      @errors = []
    end
  end

# Dummy parser - does nothing
# Returns the original params back
  class RightDummyParser # :nodoc:
    attr_accessor :result

    def parse(response, params={})
      @result = [response, params]
    end
  end

  class RightHttp2xxParser < AwsParser # :nodoc:
    def parse(response)
      @result = response.is_a?(Net::HTTPSuccess)
    end
  end
end