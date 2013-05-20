require 'rubygems'
require 'rake'

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'doc'
  rdoc.title = "iron_mq #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Test just the SQS interface"
task :testsqs do
    require 'test/test_credentials'
    require 'test/http_connection'
    TestCredentials.get_credentials
    require 'test/sqs/test_sqs.rb'
end

desc "Test just the S3 interface"
task :tests3 do
    require 'test/test_credentials'
    require 'test/http_connection'
    TestCredentials.get_credentials
    require 'test/s3/test_s3.rb'
end

desc "Test just the S3 interface using local stubs"
task :tests3local do
    require 'test/test_credentials'
    require 'test/http_connection'
    TestCredentials.get_credentials
    require 'test/s3/test_s3_stubbed.rb'
end

desc "Test just the EC2 interface"
task :testec2 do
    require 'test/test_credentials'
    TestCredentials.get_credentials
    require 'test/ec2/test_ec2.rb'
end

desc "Test just the SDB interface"
task :testsdb do
    require 'test/test_credentials'
    TestCredentials.get_credentials
    require 'test/sdb/test_sdb.rb'
end

desc "Test CloudFront interface"
task :testacf do
    require 'test/test_credentials'
    TestCredentials.get_credentials
    require 'test/acf/test_acf.rb'
end
