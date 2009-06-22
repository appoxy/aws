# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{aws}
  s.version = "1.11.17"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Travis Reeder", "RightScale"]
  s.date = %q{2009-06-16}
  s.description = %q{AWS Library for amazon web services.}
  s.email = %q{travis@appoxy.com}
  s.extra_rdoc_files = [
    "README.markdown"
  ]
  s.files = [
    "lib/acf/right_acf_interface.rb",
     "lib/awsbase/benchmark_fix.rb",
     "lib/awsbase/right_awsbase.rb",
     "lib/awsbase/support.rb",
     "lib/ec2/right_ec2.rb",
     "lib/right_aws.rb",
     "lib/s3/right_s3.rb",
     "lib/s3/right_s3_interface.rb",
     "lib/sdb/active_sdb.rb",
     "lib/sdb/right_sdb_interface.rb",
     "lib/sqs/right_sqs.rb",
     "lib/sqs/right_sqs_gen2.rb",
     "lib/sqs/right_sqs_gen2_interface.rb",
     "lib/sqs/right_sqs_interface.rb"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/appoxy/aws/}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{AWS Library for amazon web services.}
  s.test_files = [
    "test/acf/test_helper.rb",
     "test/acf/test_right_acf.rb",
     "test/ec2/test_helper.rb",
     "test/ec2/test_right_ec2.rb",
     "test/http_connection.rb",
     "test/s3/test_helper.rb",
     "test/s3/test_right_s3.rb",
     "test/s3/test_right_s3_stubbed.rb",
     "test/sdb/test_active_sdb.rb",
     "test/sdb/test_helper.rb",
     "test/sdb/test_right_sdb.rb",
     "test/sqs/test_helper.rb",
     "test/sqs/test_right_sqs.rb",
     "test/sqs/test_right_sqs_gen2.rb",
     "test/test_credentials.rb",
     "test/ts_right_aws.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
