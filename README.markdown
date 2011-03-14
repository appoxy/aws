# Appoxy AWS Library

A Ruby gem for all Amazon Web Services.

Brought to you by: [![Appoxy](https://lh5.googleusercontent.com/_-J9DSaseOX8/TX2Bq564w-I/AAAAAAAAxYU/xjeReyoxa8o/s800/appoxy-small%20%282%29.png)](http://www.appoxy.com)

## Discussion Group

[http://groups.google.com/group/ruby-aws](http://groups.google.com/group/ruby-aws)

## Documentation

[Ruby Docs](http://rubydoc.info/gems/aws/2.4.5/frames)

## Appoxy Amazon Web Services Ruby Gems

Published by [Appoxy LLC](http://www.appoxy.com), under the MIT License. Special thanks to RightScale from which this project is forked.

## INSTALL:

    gem install aws

Then `require 'aws'` in your application.

## DESCRIPTION:

The AWS gems have been designed to provide a robust, fast, and secure interface to Amazon EC2, EBS, S3, SQS, SDB, and
CloudFront.
The AWS gems comprise:

- Aws::Ec2 -- interface to Amazon EC2 (Elastic Compute Cloud) and the associated EBS (Elastic Block Store)
- Aws::S3 and Aws::S3Interface -- interface to Amazon S3 (Simple Storage Service)
- Aws::Sqs and Aws::SqsInterface -- interface to Amazon SQS (Simple Queue Service)
- Aws::SdbInterface -- interface to Amazon SDB (SimpleDB). See [SimpleRecord for an ActiveRecord like gem](https://github.com/appoxy/simple_record).
- Aws::AcfInterface -- interface to Amazon CloudFront, a content distribution service
- Aws::ElbInterface -- interface to Amazon Load Balancing service
- Aws::MonInterface -- interface to Amazon CloudWatch monitoring service
- Aws::Iam -- for AWS Identity and Access Management

To use a single piece intead of loading all of then, you can require it explicitly for example: `require 'aws/sqs'`.

## FEATURES:

- Full programmmatic access to EC2, EBS, S3, SQS, SDB, ELB, and CloudFront.
- Complete error handling: all operations check for errors and report complete
  error information by raising an AwsError.
- Persistent HTTP connections with robust network-level retry layer using
  RightHttpConnection).  This includes socket timeouts and retries.
- Robust HTTP-level retry layer.  Certain (user-adjustable) HTTP errors returned
  by Amazon's services are classified as temporary errors.
  These errors are automaticallly retried using exponentially increasing intervals.
  The number of retries is user-configurable.
- Fast REXML-based parsing of responses (as fast as a pure Ruby solution allows).
- Uses libxml (if available) for faster response parsing. 
- Support for large S3 list operations.  Buckets and key subfolders containing
  many (> 1000) keys are listed in entirety.  Operations based on list (like
  bucket clear) work on arbitrary numbers of keys.
- Support for streaming GETs from S3, and streaming PUTs to S3 if the data source is a file.
- Support for single-threaded usage, multithreaded usage, as well as usage with multiple
  AWS accounts.
- Support for both first- and second-generation SQS (API versions 2007-05-01
  and 2008-01-01).  These versions of SQS are not compatible.
- Support for signature versions 0, 1 and 2 on all services.
- Interoperability with any cloud running Eucalyptus (http://eucalyptus.cs.ucsb.edu)
- Test suite (requires AWS account to do "live" testing).

## THREADING:

All AWS interfaces offer three threading options:

1. Use a single persistent HTTP connection per process. :single
2. Use a persistent HTTP connection per Ruby thread. :per_thread
3. Open a new connection for each request. :per_request
 
Either way, it doesn't matter how many (for example) Aws::S3 objects you create,
they all use the same per-program or per-thread
connection. The purpose of sharing the connection is to keep a single
persistent HTTP connection open to avoid paying connection
overhead on every request. However, if you have multiple concurrent
threads, you may want or need an HTTP connection per thread to enable
concurrent requests to AWS. The way this plays out in practice is:

1. If you have a non-multithreaded Ruby program, use the non-multithreaded setting.
2. If you have a multi-threaded Ruby program, use the multithreaded setting to enable
   concurrent requests to S3 (or SQS, or SDB, or EC2).
3. For running under Mongrel/Rails, use the non-multithreaded setting even though
   mongrel is multithreaded.  This is because only one Rails handler is invoked at
   time (i.e. it acts like a single-threaded program)

Note that due to limitations in the I/O of the Ruby interpreter you
may not get the degree of parallelism you may expect with the multi-threaded setting.

By default, EC2/S3/SQS/SDB/ACF interface instances are created in per_request mode.  Set
params[:connection_mode] to :per_thread in the initialization arguments to use
multithreaded mode.


== LICENSE:

Copyright (c) 2007-2009 RightScale, Inc. 

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
