# encoding: utf-8
require File.dirname(__FILE__) + '/test_helper.rb'
require_relative 's3_test_base'
require File.dirname(__FILE__) + '/../test_credentials.rb'

class TestS3Class < S3TestBase

  #---------------------------
  # Aws::S3 classes
  #---------------------------

  def test_20_s3
    # create bucket
    bucket = @s.bucket(@bucket, true)
    assert bucket
    # check that the bucket exists
    assert @s.buckets.map { |b| b.name }.include?(@bucket)
    # delete bucket
    assert bucket.clear
    assert bucket.delete
  end

  def test_21_bucket_create_put_get_key
    bucket = Aws::S3::Bucket.create(@s, @bucket, true)
    # check that the bucket exists
    assert @s.buckets.map { |b| b.name }.include?(@bucket)
    assert bucket.keys.empty?, "keys are not empty: " + bucket.keys.inspect
    # put data
    assert bucket.put(@key3, RIGHT_OBJECT_TEXT, {'family'=>'123456'})
    # get data and compare
    assert_equal RIGHT_OBJECT_TEXT, bucket.get(@key3)
    # get key object
    key = bucket.key(@key3, true)
    assert_equal Aws::S3::Key, key.class
    assert key.exists?
    assert_equal '123456', key.meta_headers['family']
  end

  def test_22_bucket_put_big_with_multibyte_chars
    bucket           = Aws::S3::Bucket.create(@s, @bucket, true)
    super_big_string = ""
    10000.times { |i| super_big_string << "abcde Café" }
    # this string has multibye values just to mess things up abit.
    puts 'String made, putting...'
    puts "#{super_big_string.size} - #{super_big_string.bytesize}"
    assert bucket.put("super_big", super_big_string), 'Put bucket fail'

    got = bucket.get("super_big")
    puts 'got.class=' + got.class.name
    assert_equal(super_big_string, got, "not the same yo")
  end

  def test_23_put_strange_things
    bucket           = Aws::S3::Bucket.create(@s, @bucket, true)

    # this is kinda bad, you put a nil, but get an empty string back
    assert bucket.put("strange", nil), 'Put bucket fail'
    got = bucket.get("strange")
    assert_equal("", got)

    x = "\xE2\x80\x99s Café"
    puts "#{x.size} - #{x.bytesize}"
    assert bucket.put("multibye", x)



  end

  def test_30_keys
    bucket = Aws::S3::Bucket.create(@s, @bucket, false)
    # create first key
    key3   = Aws::S3::Key.create(bucket, @key3)
    key3.refresh
    assert key3.exists?
    assert_equal '123456', key3.meta_headers['family']
    # create second key
    key2 = Aws::S3::Key.create(bucket, @key2)
    assert !key2.refresh
    assert !key2.exists?
    assert_raise(Aws::AwsError) { key2.head }
    # store key
    key2.meta_headers = {'family'=>'111222333'}
    assert key2.put(RIGHT_OBJECT_TEXT)
    # make sure that the key exists
    assert key2.refresh
    assert key2.exists?
    assert key2.head
    # get its data
    assert_equal RIGHT_OBJECT_TEXT, key2.get
    # drop key
    assert key2.delete
    assert !key2.exists?
  end

  def test_31_rename_key
    bucket = Aws::S3::Bucket.create(@s, @bucket, false)
    # -- 1 -- (key based rename)
    # create a key
    key    = bucket.key('test/copy/1')
    key.put(RIGHT_OBJECT_TEXT)
    original_key = key.clone
    assert key.exists?, "'test/copy/1' should exist"
    # rename it
    key.rename('test/copy/2')
    assert_equal 'test/copy/2', key.name
    assert key.exists?, "'test/copy/2' should exist"
    # the original key should not exist
    assert !original_key.exists?, "'test/copy/1' should not exist"
    # -- 2 -- (bucket based rename)
    bucket.rename_key('test/copy/2', 'test/copy/3')
    assert bucket.key('test/copy/3').exists?, "'test/copy/3' should exist"
    assert !bucket.key('test/copy/2').exists?, "'test/copy/2' should not exist"
  end

  def test_32_copy_key
    bucket = Aws::S3::Bucket.create(@s, @bucket, false)
    # -- 1 -- (key based copy)
    # create a key
    key    = bucket.key('test/copy/10')
    key.put(RIGHT_OBJECT_TEXT)
    # make copy
    new_key = key.copy('test/copy/11')
    # make sure both the keys exist and have a correct data
    assert key.exists?, "'test/copy/10' should exist"
    assert new_key.exists?, "'test/copy/11' should exist"
    assert_equal RIGHT_OBJECT_TEXT, key.get
    assert_equal RIGHT_OBJECT_TEXT, new_key.get
    # -- 2 -- (bucket based copy)
    bucket.copy_key('test/copy/11', 'test/copy/12')
    assert bucket.key('test/copy/11').exists?, "'test/copy/11' should exist"
    assert bucket.key('test/copy/12').exists?, "'test/copy/12' should exist"
    assert_equal RIGHT_OBJECT_TEXT, bucket.key('test/copy/11').get
    assert_equal RIGHT_OBJECT_TEXT, bucket.key('test/copy/12').get
  end

  def test_33_move_key
    bucket = Aws::S3::Bucket.create(@s, @bucket, false)
    # -- 1 -- (key based copy)
    # create a key
    key    = bucket.key('test/copy/20')
    key.put(RIGHT_OBJECT_TEXT)
    # move
    new_key = key.move('test/copy/21')
    # make sure both the keys exist and have a correct data
    assert !key.exists?, "'test/copy/20' should not exist"
    assert new_key.exists?, "'test/copy/21' should exist"
    assert_equal RIGHT_OBJECT_TEXT, new_key.get
    # -- 2 -- (bucket based copy)
    bucket.copy_key('test/copy/21', 'test/copy/22')
    assert bucket.key('test/copy/21').exists?, "'test/copy/21' should not exist"
    assert bucket.key('test/copy/22').exists?, "'test/copy/22' should exist"
    assert_equal RIGHT_OBJECT_TEXT, bucket.key('test/copy/22').get
  end

  def test_40_save_meta
    bucket = Aws::S3::Bucket.create(@s, @bucket, false)
    # create a key
    key    = bucket.key('test/copy/30')
    key.put(RIGHT_OBJECT_TEXT)
    assert key.meta_headers.blank?
    # store some meta keys
    meta = {'family' => 'oops', 'race' => 'troll'}
    assert_equal meta, key.save_meta(meta)
    # reload meta
    assert_equal meta, key.reload_meta
  end

  def test_60_clear_delete
    bucket = Aws::S3::Bucket.create(@s, @bucket, false)
    # add another key
    bucket.put(@key2, RIGHT_OBJECT_TEXT)
    # delete 'folder'
    assert_equal 1, bucket.delete_folder(@key1).size
    # delete
    assert_raise(Aws::AwsError) { bucket.delete }
    assert bucket.delete(true)
  end

end