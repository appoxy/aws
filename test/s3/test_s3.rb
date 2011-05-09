require File.dirname(__FILE__) + '/test_helper.rb'
require_relative 's3_test_base'
require File.dirname(__FILE__) + '/../test_credentials.rb'

class TestS3 < S3TestBase

  #---------------------------
  # Aws::S3Interface
  #---------------------------

  def test_01_create_bucket
    assert @s3.create_bucket(@bucket), 'Create_bucket fail'
  end

  def test_02_list_all_my_buckets
    assert @s3.list_all_my_buckets.map { |bucket| bucket[:name] }.include?(@bucket), "#{@bucket} must exist in bucket list"
  end

  def test_03_list_empty_bucket
    assert_equal 0, @s3.list_bucket(@bucket).size, "#{@bucket} isn't empty, arrgh!"
  end

  def test_04_put
    assert @s3.put(@bucket, @key1, RIGHT_OBJECT_TEXT, 'x-amz-meta-family'=>'Woohoo1!'), 'Put bucket fail'
    assert @s3.put(@bucket, @key2, RIGHT_OBJECT_TEXT, 'x-amz-meta-family'=>'Woohoo2!'), 'Put bucket fail'
    assert @s3.put(@bucket, @key3, RIGHT_OBJECT_TEXT, 'x-amz-meta-family'=>'Woohoo3!'), 'Put bucket fail'
  end

  def test_04a_put
    super_big_string = ""
    1000000.times {|i| super_big_string << "abcde" }
    assert @s3.put(@bucket, "super_big", super_big_string), 'Put bucket fail'
  end

  def test_05_get_and_get_object
    assert_raise(Aws::AwsError) { @s3.get(@bucket, 'undefined/key') }
    data1 = @s3.get(@bucket, @key1)
    assert_equal RIGHT_OBJECT_TEXT, data1[:object], "Object text must be equal to '#{RIGHT_OBJECT_TEXT}'"
    assert_equal RIGHT_OBJECT_TEXT, @s3.get_object(@bucket, @key1), "Get_object text must return '#{RIGHT_OBJECT_TEXT}'"
    assert_equal 'Woohoo1!', data1[:headers]['x-amz-meta-family'], "x-amz-meta-family header must be equal to 'Woohoo1!'"
    assert_equal RIGHT_OBJECT_TEXT, @s3.get_object(@bucket, @key3), "Get_object text must return '#{RIGHT_OBJECT_TEXT}'"
  end

  def test_06_head
    assert_equal 'Woohoo1!', @s3.head(@bucket, @key1)['x-amz-meta-family'], "x-amz-meta-family header must be equal to 'Woohoo1!'"
  end


  def test_07_streaming_get
    resp = String.new
    assert_raise(Aws::AwsError) do
      @s3.get(@bucket, 'undefined/key') do |chunk|
        resp += chunk
      end
    end

    resp  = String.new
    data1 = @s3.get(@bucket, @key1) do |chunk|
      resp += chunk
    end
    assert_equal RIGHT_OBJECT_TEXT, resp, "Object text must be equal to '#{RIGHT_OBJECT_TEXT}'"
    assert_equal @s3.get_object(@bucket, @key1), resp, "Streaming iface must return same as non-streaming"
    assert_equal 'Woohoo1!', data1[:headers]['x-amz-meta-family'], "x-amz-meta-family header must be equal to 'Woohoo1!'"
  end

  def test_08_keys
    keys = @s3.list_bucket(@bucket).map { |b| b[:key] }
    assert_equal keys.size, 3, "There should be 3 keys"
    assert(keys.include?(@key1))
    assert(keys.include?(@key2))
    assert(keys.include?(@key3))
  end

  def test_09_copy_key
    #--- test COPY
    # copy a key
    assert @s3.copy(@bucket, @key1, @bucket, @key1_copy)
    # check it was copied well
    assert_equal RIGHT_OBJECT_TEXT, @s3.get_object(@bucket, @key1_copy), "copied object must have the same data"
    # check meta-headers were copied
    headers = @s3.head(@bucket, @key1_copy)
    assert_equal 'Woohoo1!', headers['x-amz-meta-family'], "x-amz-meta-family header must be equal to 'Woohoo1!'"
    #--- test REPLACE
    assert @s3.copy(@bucket, @key1, @bucket, @key1_copy, :replace, 'x-amz-meta-family' => 'oooops!')
    # check it was copied well
    assert_equal RIGHT_OBJECT_TEXT, @s3.get_object(@bucket, @key1_copy), "copied object must have the same data"
    # check meta-headers were overwrittenn
    headers = @s3.head(@bucket, @key1_copy)
    assert_equal 'oooops!', headers['x-amz-meta-family'], "x-amz-meta-family header must be equal to 'oooops!'"
  end

  def test_10_move_key
    # move a key
    assert @s3.move(@bucket, @key1, @bucket, @key1_new_name)
    # check it's data was moved correctly
    assert_equal RIGHT_OBJECT_TEXT, @s3.get_object(@bucket, @key1_new_name), "moved object must have the same data"
    # check meta-headers were moved
    headers = @s3.head(@bucket, @key1_new_name)
    assert_equal 'Woohoo1!', headers['x-amz-meta-family'], "x-amz-meta-family header must be equal to 'Woohoo1!'"
    # check the original key is not exists any more
    keys = @s3.list_bucket(@bucket).map { |b| b[:key] }
    assert(!keys.include?(@key1))
  end

  def test_11_rename_key
    # rename a key
    assert @s3.rename(@bucket, @key2, @key2_new_name)
    # check the new key data
    assert_equal RIGHT_OBJECT_TEXT, @s3.get_object(@bucket, @key2_new_name), "moved object must have the same data"
    # check meta-headers
    headers = @s3.head(@bucket, @key2_new_name)
    assert_equal 'Woohoo2!', headers['x-amz-meta-family'], "x-amz-meta-family header must be equal to 'Woohoo2!'"
    # check the original key is not exists any more
    keys = @s3.list_bucket(@bucket).map { |b| b[:key] }
    assert(!keys.include?(@key2))
  end

  def test_12_retrieve_object
    assert_raise(Aws::AwsError) { @s3.retrieve_object(:bucket => @bucket, :key => 'undefined/key') }
    data1 = @s3.retrieve_object(:bucket => @bucket, :key => @key1_new_name)
    assert_equal RIGHT_OBJECT_TEXT, data1[:object], "Object text must be equal to '#{RIGHT_OBJECT_TEXT}'"
    assert_equal 'Woohoo1!', data1[:headers]['x-amz-meta-family'], "x-amz-meta-family header must be equal to 'Woohoo1!'"
  end

  def test_13_delete_folder
    assert_equal 1, @s3.delete_folder(@bucket, 'test').size, "Only one key(#{@key1}) must be deleted!"
  end

  # idle timeout is 20 seconds
  # https://forums.aws.amazon.com/thread.jspa?threadID=58038
  def test_14_idle_timeout
    @s3 = Aws::S3Interface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key,
                               :connection_mode=>:single)
    # Disable connection retrying
    Aws::AWSErrorHandler.close_on_error = false
    assert @s3.put(@bucket, @key1, RIGHT_OBJECT_TEXT, 'x-amz-meta-family'=>'Woohoo1!'), 'Put bucket fail'
    sleep 300
    assert_raises Aws::AwsError do
      @s3.put(@bucket, @key2, RIGHT_OBJECT_TEXT, 'x-amz-meta-family'=>'Woohoo1!')
    end

    # now try again with retry mode
     @s3 = Aws::S3Interface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key,
                               :connection_mode=>:single)
    Aws::AWSErrorHandler.close_on_error = true
    assert @s3.put(@bucket, @key1, RIGHT_OBJECT_TEXT, 'x-amz-meta-family'=>'Woohoo1!'), 'Put bucket fail'
    sleep 30
    assert @s3.put(@bucket, @key2, RIGHT_OBJECT_TEXT, 'x-amz-meta-family'=>'Woohoo1!'), 'Put bucket fail'


  end

  def test_99_delete_bucket
    assert_raise(Aws::AwsError) { @s3.delete_bucket(@bucket) }
    assert @s3.clear_bucket(@bucket), 'Clear_bucket fail'
    assert_equal 0, @s3.list_bucket(@bucket).size, 'Bucket must be empty'
    assert @s3.delete_bucket(@bucket)
    assert !@s3.list_all_my_buckets.map { |bucket| bucket[:name] }.include?(@bucket), "#{@bucket} must not exist"
  end


end
