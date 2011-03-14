require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/aws'
require 'pp'
require File.dirname(__FILE__) + '/../test_credentials.rb'

class TestSes < Test::Unit::TestCase

  def setup
    TestCredentials.get_credentials

    @ses = Aws::Ses.new(TestCredentials.aws_access_key_id,
                        TestCredentials.aws_secret_access_key)

  end

  def test_01_get_send_quota

    ret = @ses.get_send_quota
    p ret
    assert_true(ret.size == 0)
  end

  def test_02_get_send_statistics
    ret = @ses.get_send_quota
    p ret
  end

  def test_10_list_verified_email_addresses

    ret = @ses.get_send_quota
    p ret
    assert_true(ret.size == 0)
  end

  def test_20_send_email

    ret = @ses.get_send_quota
    p ret
    assert_true(ret.size == 0)
  end

  def test_30_send_raw_email

    ret = @ses.get_send_quota
    p ret
    assert_true(ret.size == 0)
  end

  def test_40_verify_email_address
    ret = @ses.get_send_quota
    p ret
    assert_true(ret.size == 0)
  end
end
