module Aws


  class S3::Key

    attr_reader :bucket, :name, :last_modified, :e_tag, :size, :storage_class, :owner
    attr_accessor :headers, :meta_headers
    attr_writer :data

    # Separate Amazon meta headers from other headers
    def self.split_meta(headers) #:nodoc:
      hash = headers.dup
      meta = {}
      hash.each do |key, value|
        if key[/^#{S3Interface::AMAZON_METADATA_PREFIX}/]
          meta[key.gsub(S3Interface::AMAZON_METADATA_PREFIX, '')] = value
          hash.delete(key)
        end
      end
      [hash, meta]
    end

    def self.add_meta_prefix(meta_headers, prefix=S3Interface::AMAZON_METADATA_PREFIX)
      meta = {}
      meta_headers.each do |meta_header, value|
        if meta_header[/#{prefix}/]
          meta[meta_header] = value
        else
          meta["#{S3Interface::AMAZON_METADATA_PREFIX}#{meta_header}"] = value
        end
      end
      meta
    end


    # Create a new Key instance, but do not create the actual key.
    # The +name+ is a +String+.
    # Returns a new Key instance.
    #
    #  key = Aws::S3::Key.create(bucket, 'logs/today/1.log') #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  key.exists?                                                  #=> true | false
    #  key.put('Woohoo!')                                           #=> true
    #  key.exists?                                                  #=> true
    #
    def self.create(bucket, name, data=nil, meta_headers={})
      new(bucket, name, data, {}, meta_headers)
    end

    # Create a new Key instance, but do not create the actual key.
    # In normal use this method should not be called directly.
    # Use Aws::S3::Key.create or bucket.key() instead.
    #
    def initialize(bucket, name, data=nil, headers={}, meta_headers={},
        last_modified=nil, e_tag=nil, size=nil, storage_class=nil, owner=nil)
      raise 'Bucket must be a Bucket instance.' unless bucket.is_a?(S3::Bucket)
      @bucket        = bucket
      @name          = name
      @data          = data
      @e_tag         = e_tag
      @size          = size.to_i
      @storage_class = storage_class
      @owner         = owner
      @last_modified = last_modified
      if @last_modified && !@last_modified.is_a?(Time)
        @last_modified = Time.parse(@last_modified)
      end
      @headers, @meta_headers = self.class.split_meta(headers)
      @meta_headers.merge!(meta_headers)
    end

    # Return key name as a String.
    #
    #  key = Aws::S3::Key.create(bucket, 'logs/today/1.log') #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  puts key                                                   #=> 'logs/today/1.log'
    #
    def to_s
      @name.to_s
    end

    # Return the full S3 path to this key (bucket/key).
    #
    #  key.full_name #=> 'my_awesome_bucket/cool_key'
    #
    def full_name(separator='/')
      "#{@bucket.to_s}#{separator}#{@name}"
    end

    # Return a public link to a key.
    #
    #  key.public_link #=> 'https://s3.amazonaws.com:443/my_awesome_bucket/cool_key'
    #
    def public_link
      params = @bucket.s3.interface.params
      "#{params[:protocol]}://#{params[:server]}:#{params[:port]}/#{full_name('/')}"
    end

    # Return Key data. Retrieve this data from Amazon if it is the first time call.
    # TODO TRB 6/19/07 What does the above mean? Clarify.
    #
    def data
      get if !@data and exists?
      @data
    end

    # Retrieve object data and attributes from Amazon.
    # Returns a +String+.
    #
    def get(headers={}, &block)
      response = @bucket.s3.interface.get(@bucket.name, @name, headers, &block)
      @data    = response[:object]
      @headers, @meta_headers = self.class.split_meta(response[:headers])
#        refresh(false) Holy moly, this was doing two extra hits to s3 for making 3 hits for every get!!
      @data
    end

    # Store object data on S3.
    # Parameter +data+ is a +String+ or S3Object instance.
    # Returns +true+.
    #
    #  key = Aws::S3::Key.create(bucket, 'logs/today/1.log')
    #  key.data = 'Qwerty'
    #  key.put             #=> true
    #   ...
    #  key.put('Olala!')   #=> true
    #
    def put(data=nil, perms=nil, headers={})
      headers['x-amz-acl'] = perms if perms
      @data = data || @data
      meta  = self.class.add_meta_prefix(@meta_headers)
      @bucket.s3.interface.put(@bucket.name, @name, @data, meta.merge(headers))
    end

    # Rename an object. Returns new object name.
    #
    #  key = Aws::S3::Key.create(bucket, 'logs/today/1.log') #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  key.rename('logs/today/2.log')   #=> 'logs/today/2.log'
    #  puts key.name                    #=> 'logs/today/2.log'
    #  key.exists?                      #=> true
    #
    def rename(new_name)
      @bucket.s3.interface.rename(@bucket.name, @name, new_name)
      @name = new_name
    end

    # Create an object copy. Returns a destination Aws::S3::Key instance.
    #
    #  # Key instance as destination
    #  key1 = Aws::S3::Key.create(bucket, 'logs/today/1.log') #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  key2 = Aws::S3::Key.create(bucket, 'logs/today/2.log') #=> #<Aws::S3::Key:0xb7b5e240 ... >
    #  key1.put('Olala!')   #=> true
    #  key1.copy(key2)      #=> #<Aws::S3::Key:0xb7b5e240 ... >
    #  key1.exists?         #=> true
    #  key2.exists?         #=> true
    #  puts key2.data       #=> 'Olala!'
    #
    #  # String as destination
    #  key = Aws::S3::Key.create(bucket, 'logs/today/777.log') #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  key.put('Olala!')                          #=> true
    #  new_key = key.copy('logs/today/888.log')   #=> #<Aws::S3::Key:0xb7b5e240 ... >
    #  key.exists?                                #=> true
    #  new_key.exists?                            #=> true
    #
    def copy(new_key_or_name)
      new_key_or_name = S3::Key.create(@bucket, new_key_or_name.to_s) unless new_key_or_name.is_a?(S3::Key)
      @bucket.s3.interface.copy(@bucket.name, @name, new_key_or_name.bucket.name, new_key_or_name.name)
      new_key_or_name
    end

    # Move an object to other location. Returns a destination Aws::S3::Key instance.
    #
    #  # Key instance as destination
    #  key1 = Aws::S3::Key.create(bucket, 'logs/today/1.log') #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  key2 = Aws::S3::Key.create(bucket, 'logs/today/2.log') #=> #<Aws::S3::Key:0xb7b5e240 ... >
    #  key1.put('Olala!')   #=> true
    #  key1.move(key2)      #=> #<Aws::S3::Key:0xb7b5e240 ... >
    #  key1.exists?         #=> false
    #  key2.exists?         #=> true
    #  puts key2.data       #=> 'Olala!'
    #
    #  # String as destination
    #  key = Aws::S3::Key.create(bucket, 'logs/today/777.log') #=> #<Aws::S3::Key:0xb7b1e240 ... >
    #  key.put('Olala!')                          #=> true
    #  new_key = key.move('logs/today/888.log')   #=> #<Aws::S3::Key:0xb7b5e240 ... >
    #  key.exists?                                #=> false
    #  new_key.exists?                            #=> true
    #
    def move(new_key_or_name)
      new_key_or_name = S3::Key.create(@bucket, new_key_or_name.to_s) unless new_key_or_name.is_a?(S3::Key)
      @bucket.s3.interface.move(@bucket.name, @name, new_key_or_name.bucket.name, new_key_or_name.name)
      new_key_or_name
    end

    # Retrieve key info from bucket and update attributes.
    # Refresh meta-headers (by calling +head+ method) if +head+ is set.
    # Returns +true+ if the key exists in bucket and +false+ otherwise.
    #
    #  key = Aws::S3::Key.create(bucket, 'logs/today/1.log')
    #  key.e_tag        #=> nil
    #  key.meta_headers #=> {}
    #  key.refresh      #=> true
    #  key.e_tag        #=> '12345678901234567890bf11094484b6'
    #  key.meta_headers #=> {"family"=>"qwerty", "name"=>"asdfg"}
    #
    def refresh(head=true)
      new_key        = @bucket.key(self)
      @last_modified = new_key.last_modified
      @e_tag         = new_key.e_tag
      @size          = new_key.size
      @storage_class = new_key.storage_class
      @owner         = new_key.owner
      if @last_modified
        self.head
        true
      else
        @headers = @meta_headers = {}
        false
      end
    end

    # Updates headers and meta-headers from S3.
    # Returns +true+.
    #
    #  key.meta_headers #=> {"family"=>"qwerty"}
    #  key.head         #=> true
    #  key.meta_headers #=> {"family"=>"qwerty", "name"=>"asdfg"}
    #
    def head
      @headers, @meta_headers = self.class.split_meta(@bucket.s3.interface.head(@bucket, @name))
      true
    end

    # Reload meta-headers only. Returns meta-headers hash.
    #
    #  key.reload_meta   #=> {"family"=>"qwerty", "name"=>"asdfg"}
    #
    def reload_meta
      @meta_headers = self.class.split_meta(@bucket.s3.interface.head(@bucket, @name)).last
    end

    # Replace meta-headers by new hash at S3. Returns new meta-headers hash.
    #
    #  key.reload_meta   #=> {"family"=>"qwerty", "name"=>"asdfg"}
    #  key.save_meta     #=> {"family"=>"oops", "race" => "troll"}
    #  key.reload_meta   #=> {"family"=>"oops", "race" => "troll"}
    #
    def save_meta(meta_headers)
      meta = self.class.add_meta_prefix(meta_headers)
      @bucket.s3.interface.copy(@bucket.name, @name, @bucket.name, @name, :replace, meta)
      @meta_headers = self.class.split_meta(meta)[1]
    end

    # Check for existence of the key in the given bucket.
    # Returns +true+ or +false+.
    #
    #  key = Aws::S3::Key.create(bucket,'logs/today/1.log')
    #  key.exists?        #=> false
    #  key.put('Woohoo!') #=> true
    #  key.exists?        #=> true
    #
    def exists?
      @bucket.key(self).last_modified ? true : false
    end

    # Remove key from bucket.
    # Returns +true+.
    #
    #  key.delete #=> true
    #
    def delete
      raise 'Key name must be specified.' if @name.blank?
      @bucket.s3.interface.delete(@bucket, @name)
    end

    # Return a list of grantees.
    #
    def grantees
      Grantee::grantees(self)
    end

  end
end
