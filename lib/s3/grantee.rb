module Aws

  # There are 2 ways to set permissions for a bucket or key (called a +thing+ below):
  #
  # 1 . Use +perms+ param to set 'Canned Access Policies' when calling the <tt>bucket.create</tt>,
  # <tt>bucket.put</tt> and <tt>key.put</tt> methods.
  # The +perms+ param can take these values: 'private', 'public-read', 'public-read-write' and
  # 'authenticated-read'.
  # (see http://docs.amazonwebservices.com/AmazonS3/2006-03-01/RESTAccessPolicy.html).
  #
  #  bucket = s3.bucket('bucket_for_kd_test_13', true, 'public-read')
  #  key.put('Woohoo!','public-read-write' )
  #
  # 2 . Use Grantee instances (the permission is a +String+ or an +Array+ of: 'READ', 'WRITE',
  # 'READ_ACP', 'WRITE_ACP', 'FULL_CONTROL'):
  #
  #  bucket  = s3.bucket('my_awesome_bucket', true)
  #  grantee1 = Aws::S3::Grantee.new(bucket, 'a123b...223c', FULL_CONTROL, :apply)
  #  grantee2 = Aws::S3::Grantee.new(bucket, 'xy3v3...5fhp', [READ, WRITE], :apply)
  #
  # There is only one way to get and to remove permission (via Grantee instances):
  #
  #  grantees = bucket.grantees # a list of Grantees that have any access for this bucket
  #  grantee1 = Aws::S3::Grantee.new(bucket, 'a123b...223c')
  #  grantee1.perms #=> returns a list of perms for this grantee to that bucket
  #    ...
  #  grantee1.drop             # remove all perms for this grantee
  #  grantee2.revoke('WRITE')  # revoke write access only
  #
  class S3::Grantee
    # A bucket or a key the grantee has an access to.
    attr_reader :thing
    # Grantee Amazon id.
    attr_reader :id
    # Grantee display name.
    attr_reader :name
    # Array of permissions.
    attr_accessor :perms

    # Retrieve Owner information and a list of Grantee instances that have
    # a access to this thing (bucket or key).
    #
    #  bucket = s3.bucket('my_awesome_bucket', true, 'public-read')
    #   ...
    #  Aws::S3::Grantee.owner_and_grantees(bucket) #=> [owner, grantees]
    #
    def self.owner_and_grantees(thing)
      if thing.is_a?(Bucket)
        bucket, key = thing, ''
      else
        bucket, key = thing.bucket, thing
      end
      hash     = bucket.s3.interface.get_acl_parse(bucket.to_s, key.to_s)
      owner    = Owner.new(hash[:owner][:id], hash[:owner][:display_name])

      grantees = []
      hash[:grantees].each do |id, params|
        grantees << new(thing, id, params[:permissions], nil, params[:display_name])
      end
      [owner, grantees]
    end

    # Retrieves a list of Grantees instances that have an access to this thing(bucket or key).
    #
    #  bucket = s3.bucket('my_awesome_bucket', true, 'public-read')
    #   ...
    #  Aws::S3::Grantee.grantees(bucket) #=> grantees
    #
    def self.grantees(thing)
      owner_and_grantees(thing)[1]
    end

    def self.put_acl(thing, owner, grantees) #:nodoc:
      if thing.is_a?(Bucket)
        bucket, key = thing, ''
      else
        bucket, key = thing.bucket, thing
      end
      body = "<AccessControlPolicy>" +
          "<Owner>" +
          "<ID>#{owner.id}</ID>" +
          "<DisplayName>#{owner.name}</DisplayName>" +
          "</Owner>" +
          "<AccessControlList>" +
          grantees.map { |grantee| grantee.to_xml }.join +
          "</AccessControlList>" +
          "</AccessControlPolicy>"
      bucket.s3.interface.put_acl(bucket.to_s, key.to_s, body)
    end

    # Create a new Grantee instance.
    # Grantee +id+ must exist on S3. If +action+ == :refresh, then retrieve
    # permissions from S3 and update @perms. If +action+ == :apply, then apply
    # perms to +thing+ at S3. If +action+ == :apply_and_refresh then it performs.
    # both the actions. This is used for the new grantees that had no perms to
    # this thing before. The default action is :refresh.
    #
    #  bucket = s3.bucket('my_awesome_bucket', true, 'public-read')
    #  grantee1 = Aws::S3::Grantee.new(bucket, 'a123b...223c', FULL_CONTROL)
    #    ...
    #  grantee2 = Aws::S3::Grantee.new(bucket, 'abcde...asdf', [FULL_CONTROL, READ], :apply)
    #  grantee3 = Aws::S3::Grantee.new(bucket, 'aaaaa...aaaa', 'READ', :apply_and_refresh)
    #
    def initialize(thing, id, perms=[], action=:refresh, name=nil)
      @thing = thing
      @id    = id
      @name  = name
      @perms = perms.to_a
      case action
        when :apply then
          apply
        when :refresh then
          refresh
        when :apply_and_refresh then
          apply; refresh
      end
    end

    # Return +true+ if the grantee has any permissions to the thing.
    def exists?
      self.class.grantees(@thing).each do |grantee|
        return true if @id == grantee.id
      end
      false
    end

    # Return Grantee type (+String+): "Group" or "CanonicalUser".
    def type
      @id[/^http:/] ? "Group" : "CanonicalUser"
    end

    # Return a name or an id.
    def to_s
      @name || @id
    end

    # Add permissions for grantee.
    # Permissions: 'READ', 'WRITE', 'READ_ACP', 'WRITE_ACP', 'FULL_CONTROL'.
    # See http://docs.amazonwebservices.com/AmazonS3/2006-03-01/UsingPermissions.html .
    # Returns +true+.
    #
    #  grantee.grant('FULL_CONTROL')                  #=> true
    #  grantee.grant('FULL_CONTROL','WRITE','READ')   #=> true
    #  grantee.grant(['WRITE_ACP','READ','READ_ACP']) #=> true
    #
    def grant(*permissions)
      permissions.flatten!
      old_perms = @perms.dup
      @perms    += permissions
      @perms.uniq!
      return true if @perms == old_perms
      apply
    end

    # Revoke permissions for grantee.
    # Permissions: 'READ', 'WRITE', 'READ_ACP', 'WRITE_ACP', 'FULL_CONTROL'
    # See http://docs.amazonwebservices.com/AmazonS3/2006-03-01/UsingPermissions.html .
    # Default value is 'FULL_CONTROL'.
    # Returns +true+.
    #
    #  grantee.revoke('READ')                   #=> true
    #  grantee.revoke('FULL_CONTROL','WRITE')   #=> true
    #  grantee.revoke(['READ_ACP','WRITE_ACP']) #=> true
    #
    def revoke(*permissions)
      permissions.flatten!
      old_perms = @perms.dup
      @perms    -= permissions
      @perms.uniq!
      return true if @perms == old_perms
      apply
    end

    # Revoke all permissions for this grantee.
    # Returns +true+.
    #
    #  grantee.drop #=> true
    #
    def drop
      @perms = []
      apply
    end

    # Refresh grantee perms for its +thing+.
    # Returns +true+ if the grantee has perms for this +thing+ or
    # +false+ otherwise, and updates @perms value as a side-effect.
    #
    #  grantee.grant('FULL_CONTROL') #=> true
    #  grantee.refresh               #=> true
    #  grantee.drop                  #=> true
    #  grantee.refresh               #=> false
    #
    def refresh
      @perms = []
      self.class.grantees(@thing).each do |grantee|
        if @id == grantee.id
          @name  = grantee.name
          @perms = grantee.perms
          return true
        end
      end
      false
    end

    # Apply current grantee @perms to +thing+. This method is called internally by the +grant+
    # and +revoke+ methods. In normal use this method should not
    # be called directly.
    #
    #  grantee.perms = ['FULL_CONTROL']
    #  grantee.apply #=> true
    #
    def apply
      @perms.uniq!
      owner, grantees = self.class.owner_and_grantees(@thing)
      # walk through all the grantees and replace the data for the current one and ...
      grantees.map! { |grantee| grantee.id == @id ? self : grantee }
      # ... if this grantee is not known - add this bad boy to a list
      grantees << self unless grantees.include?(self)
      # set permissions
      self.class.put_acl(@thing, owner, grantees)
    end

    def to_xml # :nodoc:
      id_str = @id[/^http/] ? "<URI>#{@id}</URI>" : "<ID>#{@id}</ID>"
      grants = ''
      @perms.each do |perm|
        grants << "<Grant>" +
            "<Grantee xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" " +
            "xsi:type=\"#{type}\">#{id_str}</Grantee>" +
            "<Permission>#{perm}</Permission>" +
            "</Grant>"
      end
      grants
    end

  end

end