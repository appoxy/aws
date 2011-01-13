
require 'benchmark'
require 'net/https'
require 'uri'
require 'time'
require "cgi"
require "base64"
require "rexml/document"
require "openssl"
require "digest/sha1"

require 'rubygems'
require 'right_http_connection'

$:.unshift(File.dirname(__FILE__))
require 'awsbase/benchmark_fix'
require 'awsbase/support'
require 'awsbase/awsbase'
require 'awsbase/aws_response_array'
require 'ec2/ec2'
require 'ec2/mon_interface'
require 's3/s3_interface'
require 's3/s3'
require 'sqs/sqs_interface'
require 'sqs/sqs'
require 'sdb/sdb_interface'
require 'acf/acf_interface'
require 'elb/elb_interface'
require 'rds/rds'
require 'iam/iam'

