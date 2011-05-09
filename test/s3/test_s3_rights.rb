require File.dirname(__FILE__) + '/test_helper.rb'
require_relative 's3_test_base'
require File.dirname(__FILE__) + '/../test_credentials.rb'

class TestS3Rights < S3TestBase
  # Grantees

  def test_30_create_bucket
    bucket = @s.bucket(@bucket, true, 'public-read')
    assert bucket
  end

  def test_31_list_grantees
    bucket   = Aws::S3::Bucket.create(@s, @bucket, false)
    # get grantees list
    grantees = bucket.grantees
    # check that the grantees count equal to 2 (root, AllUsers)
    assert_equal 2, grantees.size
  end

  def test_32_grant_revoke_drop
    bucket  = Aws::S3::Bucket.create(@s, @bucket, false)
    # Take 'AllUsers' grantee
    grantee = Aws::S3::Grantee.new(bucket, 'http://acs.amazonaws.com/groups/global/AllUsers')
    # Check exists?
    assert grantee.exists?
    # Add grant as String
    assert grantee.grant('WRITE')
    # Add grants as Array
    assert grantee.grant(['READ_ACP', 'WRITE_ACP'])
    # Check perms count
    assert_equal 4, grantee.perms.size
    # revoke 'WRITE_ACP'
    assert grantee.revoke('WRITE_ACP')
    # Check manual perm removal method
    grantee.perms -= ['READ_ACP']
    grantee.apply
    assert_equal 2, grantee.perms.size
    # Check grantee removal if it has no permissions
    assert grantee.perms = []
    assert grantee.apply
    assert !grantee.exists?
    # Check multiple perms assignment
    assert grantee.grant('FULL_CONTROL', 'READ', 'WRITE')
    assert_equal ['FULL_CONTROL', 'READ', 'WRITE'].sort, grantee.perms.sort
    # Check multiple perms removal
    assert grantee.revoke('FULL_CONTROL', 'WRITE')
    assert_equal ['READ'], grantee.perms
    # check 'Drop' method
    assert grantee.drop
    assert !grantee.exists?
    assert_equal 1, bucket.grantees.size
    # Delete bucket
    bucket.delete(true)
  end

  def test_33_key_grantees
    # Create bucket
    bucket = @s.bucket(@bucket, true)
    # Create key
    key    = bucket.key(@key1)
    assert key.put(RIGHT_OBJECT_TEXT, 'public-read')
    # Get grantees list (must be == 2)
    grantees = key.grantees
    assert grantees
    assert_equal 2, grantees.size
    # Take one of grantees and give him 'Write' perms
    grantee = grantees[0]
    assert grantee.grant('WRITE')
    # Drop grantee
    assert grantee.drop
    # Drop bucket
    bucket.delete(true)
  end

  def test_34_bucket_create_put_with_perms
    bucket = Aws::S3::Bucket.create(@s, @bucket, true)
    # check that the bucket exists
    assert @s.buckets.map { |b| b.name }.include?(@bucket)
    assert bucket.keys.empty?
    # put data (with canned ACL)
    assert bucket.put(@key1, RIGHT_OBJECT_TEXT, {'family'=>'123456'}, "public-read")
    # get data and compare
    assert_equal RIGHT_OBJECT_TEXT, bucket.get(@key1)
    # get key object
    key = bucket.key(@key1, true)
    assert_equal Aws::S3::Key, key.class
    assert key.exists?
    assert_equal '123456', key.meta_headers['family']
  end

  def test_35_key_put_with_perms
    bucket = Aws::S3::Bucket.create(@s, @bucket, false)
    # create first key
    key1   = Aws::S3::Key.create(bucket, @key1)
    key1.refresh
    assert key1.exists?
    assert key1.put(RIGHT_OBJECT_TEXT, "public-read")
    # get its data
    assert_equal RIGHT_OBJECT_TEXT, key1.get
    # drop key
    assert key1.delete
    assert !key1.exists?
  end

  def test_36_set_amazon_problems
    original_problems = Aws::S3Interface.amazon_problems
    assert(original_problems.length > 0)
    Aws::S3Interface.amazon_problems= original_problems << "A New Problem"
    new_problems                    = Aws::S3Interface.amazon_problems
    assert_equal(new_problems, original_problems)

    Aws::S3Interface.amazon_problems= nil
    assert_nil(Aws::S3Interface.amazon_problems)
  end

  def test_37_access_logging
    bucket       = Aws::S3::Bucket.create(@s, @bucket, false)
    targetbucket = Aws::S3::Bucket.create(@s, @bucket2, true)
    # Take 'AllUsers' grantee
    grantee      = Aws::S3::Grantee.new(targetbucket, 'http://acs.amazonaws.com/groups/s3/LogDelivery')

    assert grantee.grant(['READ_ACP', 'WRITE'])

    assert bucket.enable_logging(:targetbucket => targetbucket, :targetprefix => "loggylogs/")

    assert_equal(bucket.logging_info, {:enabled => true, :targetbucket => @bucket2, :targetprefix => "loggylogs/"})

    assert bucket.disable_logging

    # check 'Drop' method
    assert grantee.drop

    # Delete bucket
    bucket.delete(true)
    targetbucket.delete(true)
  end

end