# -*- ruby -*-

require 'rubygems'
#require "rake/testtask"
#require 'rcov/rcovtask'
$: << File.dirname(__FILE__)
require 'lib/right_aws.rb'

testglobs = ["test/ts_right_aws.rb"]

begin
    require 'jeweler'
    Jeweler::Tasks.new do |gem|
        gem.name = "aws"
        gem.summary = "AWS Ruby Library for interfacing with Amazon Web Services."
        gem.email = "travis@appoxy.com"
        gem.homepage = "http://github.com/appoxy/aws/"
        gem.description = "AWS Ruby Library for interfacing with Amazon Web Services."
        gem.authors = ["Travis Reeder", "Chad Arimura", "RightScale"]
        gem.files = FileList['lib/**/*.rb']
        gem.add_dependency 'uuidtools'
        gem.add_dependency 'http_connection'
        gem.add_dependency 'xml-simple'
    end
rescue LoadError
    puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

#desc "Analyze code coverage of the unit tests."
#Rcov::RcovTask.new do |t|
#  t.test_files = FileList[testglobs]
#  t.verbose = true     # uncomment to see the executed command
#end

desc "Test just the SQS interface"
task :testsqs do
    require 'test/test_credentials'
    require 'test/http_connection'
    TestCredentials.get_credentials
    require 'test/sqs/test_sqs.rb'
end

desc "Test just the second generation SQS interface"
task :testsqs2 do
    require 'test/test_credentials'
    require 'test/http_connection'
    TestCredentials.get_credentials
    require 'test/sqs/test_right_sqs_gen2.rb'
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

desc "Test active SDB interface"
task :testactivesdb do
    require 'test/test_credentials'
    TestCredentials.get_credentials
    require 'test/sdb/test_active_sdb.rb'
end

desc "Test CloudFront interface"
task :testacf do
    require 'test/test_credentials'
    TestCredentials.get_credentials
    require 'test/acf/test_acf.rb'
end

# vim: syntax=Ruby
