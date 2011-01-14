module Aws


  class S3::Bucket
    attr_reader :s3, :name, :owner, :creation_date

    # Create a Bucket instance.
    # If the bucket does not exist and +create+ is set, a new bucket
    # is created on S3. Launching this method with +create+=+true+ may
    # affect on the bucket's ACL if the bucket already exists.
    # Returns Bucket instance or +nil+ if the bucket does not exist
    # and +create+ is not set.
    #
    #  s3 = Aws::S3.new(aws_access_key_id, aws_secret_access_key)
    #   ...
    #  bucket1 = Aws::S3::Bucket.create(s3, 'my_awesome_bucket_1')
    #  bucket1.keys  #=> exception here if the bucket does not exists
    #   ...
    #  bucket2 = Aws::S3::Bucket.create(s3, 'my_awesome_bucket_2', true)
    #  bucket2.keys  #=> list of keys
    #  # create a bucket at the European location with public read access
    #  bucket3 = Aws::S3::Bucket.create(s3,'my-awesome-bucket-3', true, 'public-read', :location => :eu)
    #
    #  see http://docs.amazonwebservices.com/AmazonS3/2006-03-01/RESTAccessPolicy.html
    #  (section: Canned Access Policies)
    #
    def self.create(s3, name, create=false, perms=nil, headers={})
      s3.bucket(name, create, perms, headers)
    end


    # Create a bucket instance. In normal use this method should
    # not be called directly.
    # Use Aws::S3::Bucket.create or Aws::S3.bucket instead.
    def initialize(s3, name, creation_date=nil, owner=nil)
      @s3            = s3
      @name          = name
      @owner         = owner
      @creation_date = creation_date
      if @creation_date && !@creation_date.is_a?(Time)
        @creation_date = Time.parse(@creation_date)
      end
    end

    # Return bucket name as a String.
    #
    #  bucket = Aws::S3.bucket('my_awesome_bucket')
    #  puts bucket #=> 'my_awesome_bucket'
    #
    def to_s
      @name.to_s
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

    # Returns the bucket location
    def location
      @location ||= @s3.interface.bucket_location(@name)
    end

    # Retrieves the logging configuration for a bucket.
    # Returns a hash of {:enabled, :targetbucket, :targetprefix}
    #
    #   bucket.logging_info()
    #   => {:enabled=>true, :targetbucket=>"mylogbucket", :targetprefix=>"loggylogs/"}
    def logging_info
      @s3.interface.get_logging_parse(:bucket => @name)
    end

    # Enables S3 server access logging on a bucket.  The target bucket must have been properly configured to receive server
    # access logs.
    #  Params:
    #   :targetbucket - either the target bucket object or the name of the target bucket
    #   :targetprefix - the prefix under which all logs should be stored
    #
    #  bucket.enable_logging(:targetbucket=>"mylogbucket", :targetprefix=>"loggylogs/")
    #    => true
    def enable_logging(params)
      AwsUtils.mandatory_arguments([:targetbucket, :targetprefix], params)
      AwsUtils.allow_only([:targetbucket, :targetprefix], params)
      xmldoc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><BucketLoggingStatus xmlns=\"http://doc.s3.amazonaws.com/2006-03-01\"><LoggingEnabled><TargetBucket>#{params[:targetbucket]}</TargetBucket><TargetPrefix>#{params[:targetprefix]}</TargetPrefix></LoggingEnabled></BucketLoggingStatus>"
      @s3.interface.put_logging(:bucket => @name, :xmldoc => xmldoc)
    end

    # Disables S3 server access logging on a bucket.  Takes no arguments.
    def disable_logging
      xmldoc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><BucketLoggingStatus xmlns=\"http://doc.s3.amazonaws.com/2006-03-01\"></BucketLoggingStatus>"
      @s3.interface.put_logging(:bucket => @name, :xmldoc => xmldoc)
    end

    # Retrieve a group of keys from Amazon.
    # +options+ is a hash: { 'prefix'=>'', 'marker'=>'', 'max-keys'=>5, 'delimiter'=>'' }).
    # Retrieves meta-headers information if +head+ it +true+.
    # Returns an array of Key instances.
    #
    #  bucket.keys                     #=> # returns all keys from bucket
    #  bucket.keys('prefix' => 'logs') #=> # returns all keys that starts with 'logs'
    #
    def keys(options={}, head=false)
      keys_and_service(options, head)[0]
    end

    # Same as +keys+ method but return an array of [keys, service_data].
    # where +service_data+ is a hash with additional output information.
    #
    #  keys, service = bucket.keys_and_service({'max-keys'=> 2, 'prefix' => 'logs'})
    #  p keys    #=> # 2 keys array
    #  p service #=> {"max-keys"=>"2", "prefix"=>"logs", "name"=>"my_awesome_bucket", "marker"=>"", "is_truncated"=>true}
    #
    def keys_and_service(options={}, head=false)
      opt = {}; options.each { |key, value| opt[key.to_s] = value }
      service_data = {}
      thislist     = {}
      list         = []
      @s3.interface.incrementally_list_bucket(@name, opt) do |thislist|
        thislist[:contents].each do |entry|
          owner = S3::Owner.new(entry[:owner_id], entry[:owner_display_name])
          key   = S3::Key.new(self, entry[:key], nil, {}, {}, entry[:last_modified], entry[:e_tag], entry[:size], entry[:storage_class], owner)
          key.head if head
          list << key
        end
      end
      thislist.each_key do |key|
        service_data[key] = thislist[key] unless (key == :contents || key == :common_prefixes)
      end
      [list, service_data]
    end

    # Retrieve key information from Amazon.
    # The +key_name+ is a +String+ or Key instance.
    # Retrieves meta-header information if +head+ is +true+.
    # Returns new Key instance.
    #
    #  key = bucket.key('logs/today/1.log', true) #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #   # is the same as:
    #  key = Aws::S3::Key.create(bucket, 'logs/today/1.log')
    #  key.head
    #
    def key(key_name, head=false)
      raise 'Key name can not be empty.' if key_name.blank?
      key_instance = nil
      # if this key exists - find it ....
      keys({'prefix'=>key_name}, head).each do |key|
        if key.name == key_name.to_s
          key_instance = key
          break
        end
      end
      # .... else this key is unknown
      unless key_instance
        key_instance = S3::Key.create(self, key_name.to_s)
      end
      key_instance
    end

    # Store object data.
    # The +key+ is a +String+ or Key instance.
    # Returns +true+.
    #
    #  bucket.put('logs/today/1.log', 'Olala!') #=> true
    #
    def put(key, data=nil, meta_headers={}, perms=nil, headers={})
      key = S3::Key.create(self, key.to_s, data, meta_headers) unless key.is_a?(S3::Key)
      key.put(data, perms, headers)
    end

    # Retrieve object data from Amazon.
    # The +key+ is a +String+ or Key.
    # Returns Key instance.
    #
    #  key = bucket.get('logs/today/1.log') #=>
    #  puts key.data #=> 'sasfasfasdf'
    #
    def get(key, headers={})
      key = S3::Key.create(self, key.to_s) unless key.is_a?(S3::Key)
      key.get(headers)
    end

    # Rename object. Returns Aws::S3::Key instance.
    #
    #  new_key = bucket.rename_key('logs/today/1.log','logs/today/2.log')   #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  puts key.name   #=> 'logs/today/2.log'
    #  key.exists?     #=> true
    #
    def rename_key(old_key_or_name, new_name)
      old_key_or_name = S3::Key.create(self, old_key_or_name.to_s) unless old_key_or_name.is_a?(S3::Key)
      old_key_or_name.rename(new_name)
      old_key_or_name
    end

    # Create an object copy. Returns a destination Aws::S3::Key instance.
    #
    #  new_key = bucket.copy_key('logs/today/1.log','logs/today/2.log')   #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  puts key.name   #=> 'logs/today/2.log'
    #  key.exists?     #=> true
    #
    def copy_key(old_key_or_name, new_key_or_name)
      old_key_or_name = S3::Key.create(self, old_key_or_name.to_s) unless old_key_or_name.is_a?(S3::Key)
      old_key_or_name.copy(new_key_or_name)
    end

    # Move an object to other location. Returns a destination Aws::S3::Key instance.
    #
    #  new_key = bucket.copy_key('logs/today/1.log','logs/today/2.log')   #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  puts key.name   #=> 'logs/today/2.log'
    #  key.exists?     #=> true
    #
    def move_key(old_key_or_name, new_key_or_name)
      old_key_or_name = S3::Key.create(self, old_key_or_name.to_s) unless old_key_or_name.is_a?(S3::Key)
      old_key_or_name.move(new_key_or_name)
    end

    # Remove all keys from a bucket.
    # Returns +true+.
    #
    #  bucket.clear #=> true
    #
    def clear
      @s3.interface.clear_bucket(@name)
    end

    # Delete all keys where the 'folder_key' can be interpreted
    # as a 'folder' name.
    # Returns an array of string keys that have been deleted.
    #
    #  bucket.keys.map{|key| key.name}.join(', ') #=> 'test, test/2/34, test/3, test1, test1/logs'
    #  bucket.delete_folder('test')               #=> ['test','test/2/34','test/3']
    #
    def delete_folder(folder, separator='/')
      @s3.interface.delete_folder(@name, folder, separator)
    end

    # Delete a bucket. Bucket must be empty.
    # If +force+ is set, clears and deletes the bucket.
    # Returns +true+.
    #
    #  bucket.delete(true) #=> true
    #
    def delete(force=false)
      force ? @s3.interface.force_delete_bucket(@name) : @s3.interface.delete_bucket(@name)
    end

    # Deletes an object from s3 in this bucket.
    def delete_key(key)
      @s3.interface.delete(name, key)
    end

    # Return a list of grantees.
    #
    def grantees
      Grantee::grantees(self)
    end

  end

end
