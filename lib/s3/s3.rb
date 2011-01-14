#
# Copyright (c) 2007-2008 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
module Aws

  # = Aws::S3 -- RightScale's Amazon S3 interface
  # The Aws::S3 class provides a complete interface to Amazon's Simple
  # Storage Service.
  # For explanations of the semantics
  # of each call, please refer to Amazon's documentation at
  # http://developer.amazonwebservices.com/connect/kbcategory.jspa?categoryID=48
  #
  # See examples below for the bucket and buckets methods.
  #
  # Error handling: all operations raise an Aws::AwsError in case
  # of problems. Note that transient errors are automatically retried.
  #
  # It is a good way to use domain naming style getting a name for the buckets.
  # See http://docs.amazonwebservices.com/AmazonS3/2006-03-01/UsingBucket.html
  # about the naming convention for the buckets. This case they can be accessed using a virtual domains.
  #
  # Let assume you have 3 buckets: 'awesome-bucket', 'awesome_bucket' and 'AWEsomE-bucket'.
  # The first ones objects can be accessed as: http:// awesome-bucket.s3.amazonaws.com/key/object
  #
  # But the rest have to be accessed as:
  # http:// s3.amazonaws.com/awesome_bucket/key/object and  http:// s3.amazonaws.com/AWEsomE-bucket/key/object
  #
  # See: http://docs.amazonwebservices.com/AmazonS3/2006-03-01/VirtualHosting.html for better explanation.
  #
  class S3


    class Owner
      attr_reader :id, :name

      def initialize(id, name)
        @id   = id
        @name = name
      end

      # Return Owner name as a +String+.
      def to_s
        @name
      end
    end

    require_relative 'bucket'
    require_relative 'key'
    require_relative 'grantee'


    attr_reader :interface


    # Create a new handle to an S3 account. All handles share the same per process or per thread
    # HTTP connection to Amazon S3. Each handle is for a specific account.
    # The +params+ are passed through as-is to Aws::S3Interface.new
    #
    # Params is a hash:
    #
    #    {:server       => 's3.amazonaws.com'   # Amazon service host: 's3.amazonaws.com'(default)
    #     :port         => 443                  # Amazon service port: 80 or 443(default)
    #     :protocol     => 'https'              # Amazon service protocol: 'http' or 'https'(default)
    #     :connection_mode  => :default         # options are
    #                                                  :default (will use best known safe (as in won't need explicit close) option, may change in the future)
    #                                                  :per_request (opens and closes a connection on every request)
    #                                                  :single (one thread across entire app)
    #                                                  :per_thread (one connection per thread)
    #     :logger       => Logger Object}       # Logger instance: logs to STDOUT if omitted }
    def initialize(aws_access_key_id=nil, aws_secret_access_key=nil, params={})
      @interface = S3Interface.new(aws_access_key_id, aws_secret_access_key, params)
    end

    def close_connection
      @interface.close_connection
    end

    # Retrieve a list of buckets.
    # Returns an array of Aws::S3::Bucket instances.
    #  # Create handle to S3 account
    #  s3 = Aws::S3.new(aws_access_key_id, aws_secret_access_key)
    #  my_buckets_names = s3.buckets.map{|b| b.name}
    #  puts "Buckets on S3: #{my_bucket_names.join(', ')}"
    def buckets
      @interface.list_all_my_buckets.map! do |entry|
        owner = Owner.new(entry[:owner_id], entry[:owner_display_name])
        Bucket.new(self, entry[:name], entry[:creation_date], owner)
      end
    end

    # Retrieve an individual bucket.
    # If the bucket does not exist and +create+ is set, a new bucket
    # is created on S3. Launching this method with +create+=+true+ may
    # affect on the bucket's ACL if the bucket already exists.
    # Returns a Aws::S3::Bucket instance or +nil+ if the bucket does not exist
    # and +create+ is not set.
    #
    #  s3 = Aws::S3.new(aws_access_key_id, aws_secret_access_key)
    #  bucket1 = s3.bucket('my_awesome_bucket_1')
    #  bucket1.keys  #=> exception here if the bucket does not exists
    #   ...
    #  bucket2 = s3.bucket('my_awesome_bucket_2', true)
    #  bucket2.keys  #=> list of keys
    #  # create a bucket at the European location with public read access
    #  bucket3 = s3.bucket('my-awesome-bucket-3', true, 'public-read', :location => :eu)
    #
    #  see http://docs.amazonwebservices.com/AmazonS3/2006-03-01/RESTAccessPolicy.html
    #  (section: Canned Access Policies)
    #
    def bucket(name, create=false, perms=nil, headers={})
      headers['x-amz-acl'] = perms if perms
      @interface.create_bucket(name, headers) if create
      return Bucket.new(self, name)
      # The old way below was too slow and unnecessary because it retreived all the buckets every time.
      #            owner = Owner.new(entry[:owner_id], entry[:owner_display_name])
#       buckets.each { |bucket| return bucket if bucket.name == name }
#      nil
    end


  end

  # Aws::S3Generator and Aws::S3Generator::Bucket methods:
  #
  #  s3g = Aws::S3Generator.new('1...2', 'nx...Y6') #=> #<Aws::S3Generator:0xb7b5cc94>
  #
  #    # List all buckets(method 'GET'):
  #  buckets_list = s3g.buckets #=> 'https://s3.amazonaws.com:443/?Signature=Y...D&Expires=1180941864&AWSAccessKeyId=1...2'
  #    # Create bucket link (method 'PUT'):
  #  bucket = s3g.bucket('my_awesome_bucket')     #=> #<Aws::S3Generator::Bucket:0xb7bcbda8>
  #  link_to_create = bucket.create_link(1.hour)  #=> https://s3.amazonaws.com:443/my_awesome_bucket?Signature=4...D&Expires=1180942132&AWSAccessKeyId=1...2
  #    # ... or:
  #  bucket = Aws::S3Generator::Bucket.create(s3g, 'my_awesome_bucket') #=> #<Aws::S3Generator::Bucket:0xb7bcbda8>
  #  link_to_create = bucket.create_link(1.hour)                                 #=> https://s3.amazonaws.com:443/my_awesome_bucket?Signature=4...D&Expires=1180942132&AWSAccessKeyId=1...2
  #    # ... or:
  #  bucket = Aws::S3Generator::Bucket.new(s3g, 'my_awesome_bucket') #=> #<Aws::S3Generator::Bucket:0xb7bcbda8>
  #  link_to_create = bucket.create_link(1.hour)                              #=> https://s3.amazonaws.com:443/my_awesome_bucket?Signature=4...D&Expires=1180942132&AWSAccessKeyId=1...2
  #    # List bucket(method 'GET'):
  #  bucket.keys(1.day) #=> https://s3.amazonaws.com:443/my_awesome_bucket?Signature=i...D&Expires=1180942620&AWSAccessKeyId=1...2
  #    # Create/put key (method 'PUT'):
  #  bucket.put('my_cool_key') #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=q...D&Expires=1180943094&AWSAccessKeyId=1...2
  #    # Get key data (method 'GET'):
  #  bucket.get('logs/today/1.log', 1.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=h...M%3D&Expires=1180820032&AWSAccessKeyId=1...2
  #    # Delete bucket (method 'DELETE'):
  #  bucket.delete(2.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/logs%2Ftoday%2F1.log?Signature=4...D&Expires=1180820032&AWSAccessKeyId=1...2
  #
  # Aws::S3Generator::Key methods:
  #
  #    # Create Key instance:
  #  key = Aws::S3Generator::Key.new(bicket, 'my_cool_key') #=> #<Aws::S3Generator::Key:0xb7b7394c>
  #    # Put key data (method 'PUT'):
  #  key.put    #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=2...D&Expires=1180943302&AWSAccessKeyId=1...2
  #    # Get key data (method 'GET'):
  #  key.get    #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=a...D&Expires=1180820032&AWSAccessKeyId=1...2
  #    # Head key (method 'HEAD'):
  #  key.head   #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=b...D&Expires=1180820032&AWSAccessKeyId=1...2
  #    # Delete key (method 'DELETE'):
  #  key.delete #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=x...D&Expires=1180820032&AWSAccessKeyId=1...2
  #
  class S3Generator
    attr_reader :interface

    def initialize(aws_access_key_id, aws_secret_access_key, params={})
      @interface = S3Interface.new(aws_access_key_id, aws_secret_access_key, params)
    end

    # Generate link to list all buckets
    #
    #  s3.buckets(1.hour)
    #
    def buckets(expires=nil, headers={})
      @interface.list_all_my_buckets_link(expires, headers)
    end

    # Create new S3LinkBucket instance and generate link to create it at S3.
    #
    #  bucket= s3.bucket('my_owesome_bucket')
    #
    def bucket(name, expires=nil, headers={})
      Bucket.create(self, name.to_s)
    end

    class Bucket
      attr_reader :s3, :name

      def to_s
        @name
      end

      alias_method :full_name, :to_s

      # Return a public link to bucket.
      #
      #  bucket.public_link #=> 'https://s3.amazonaws.com:443/my_awesome_bucket'
      #
      def public_link
        params = @s3.interface.params
        "#{params[:protocol]}://#{params[:server]}:#{params[:port]}/#{full_name}"
      end

      #  Create new S3LinkBucket instance and generate creation link for it.
      def self.create(s3, name, expires=nil, headers={})
        new(s3, name.to_s)
      end

      #  Create new S3LinkBucket instance.
      def initialize(s3, name)
        @s3, @name = s3, name.to_s
      end

      # Return a link to create this bucket.
      #
      def create_link(expires=nil, headers={})
        @s3.interface.create_bucket_link(@name, expires, headers)
      end

      # Generate link to list keys.
      #
      #  bucket.keys
      #  bucket.keys('prefix'=>'logs')
      #
      def keys(options=nil, expires=nil, headers={})
        @s3.interface.list_bucket_link(@name, options, expires, headers)
      end

      # Return a S3Generator::Key instance.
      #
      #  bucket.key('my_cool_key').get    #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=B...D&Expires=1180820032&AWSAccessKeyId=1...2
      #  bucket.key('my_cool_key').delete #=> https://s3.amazonaws.com:443/my_awesome_bucket/my_cool_key?Signature=B...D&Expires=1180820098&AWSAccessKeyId=1...2
      #
      def key(name)
        Key.new(self, name)
      end

      # Generates link to PUT key data.
      #
      #  puts bucket.put('logs/today/1.log', 2.hour)
      #
      def put(key, meta_headers={}, expires=nil, headers={})
        meta = Aws::S3::Key.add_meta_prefix(meta_headers)
        @s3.interface.put_link(@name, key.to_s, nil, expires, meta.merge(headers))
      end

      # Generate link to GET key data.
      #
      #  bucket.get('logs/today/1.log', 1.hour)
      #
      def get(key, expires=nil, headers={})
        @s3.interface.get_link(@name, key.to_s, expires, headers)
      end

      # Generate link to delete bucket.
      #
      #  bucket.delete(2.hour)
      #
      def delete(expires=nil, headers={})
        @s3.interface.delete_bucket_link(@name, expires, headers)
      end
    end


    class Key
      attr_reader :bucket, :name

      def to_s
        @name
      end

      # Return a full S# name (bucket/key).
      #
      #  key.full_name #=> 'my_awesome_bucket/cool_key'
      #
      def full_name(separator='/')
        "#{@bucket.to_s}#{separator}#{@name}"
      end

      # Return a public link to key.
      #
      #  key.public_link #=> 'https://s3.amazonaws.com:443/my_awesome_bucket/cool_key'
      #
      def public_link
        params = @bucket.s3.interface.params
        "#{params[:protocol]}://#{params[:server]}:#{params[:port]}/#{full_name('/')}"
      end

      def initialize(bucket, name, meta_headers={})
        @bucket       = bucket
        @name         = name.to_s
        @meta_headers = meta_headers
        raise 'Key name can not be empty.' if @name.blank?
      end

      # Generate link to PUT key data.
      #
      #  puts bucket.put('logs/today/1.log', '123', 2.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/logs%2Ftoday%2F1.log?Signature=B...D&Expires=1180820032&AWSAccessKeyId=1...2
      #
      def put(expires=nil, headers={})
        @bucket.put(@name.to_s, @meta_headers, expires, headers)
      end

      # Generate link to GET key data.
      #
      #  bucket.get('logs/today/1.log', 1.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/logs%2Ftoday%2F1.log?Signature=h...M%3D&Expires=1180820032&AWSAccessKeyId=1...2
      #
      def get(expires=nil, headers={})
        @bucket.s3.interface.get_link(@bucket.to_s, @name, expires, headers)
      end

      # Generate link to delete key.
      #
      #  bucket.delete(2.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/logs%2Ftoday%2F1.log?Signature=4...D&Expires=1180820032&AWSAccessKeyId=1...2
      #
      def delete(expires=nil, headers={})
        @bucket.s3.interface.delete_link(@bucket.to_s, @name, expires, headers)
      end

      # Generate link to head key.
      #
      #  bucket.head(2.hour) #=> https://s3.amazonaws.com:443/my_awesome_bucket/logs%2Ftoday%2F1.log?Signature=4...D&Expires=1180820032&AWSAccessKeyId=1...2
      #
      def head(expires=nil, headers={})
        @bucket.s3.interface.head_link(@bucket.to_s, @name, expires, headers)
      end
    end
  end

end
