class S3TestBase < Test::Unit::TestCase

   RIGHT_OBJECT_TEXT = 'Right test message'

   def setup
       TestCredentials.get_credentials
       @s3 = Aws::S3Interface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key)
       @bucket = TestCredentials.config['amazon']['my_prefix'] + '_awesome_test_bucket_000A1'
       @bucket2 = TestCredentials.config['amazon']['my_prefix'] + '_awesome_test_bucket_000A2'
       @key1 = 'test/woohoo1/'
       @key2 = 'test1/key/woohoo2'
       @key3 = 'test2/A%B@C_D&E?F+G=H"I'
       @key1_copy = 'test/woohoo1_2'
       @key1_new_name = 'test/woohoo1_3'
       @key2_new_name = 'test1/key/woohoo2_new'
       @s = Aws::S3.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key)
   end

   def teardown

   end

end