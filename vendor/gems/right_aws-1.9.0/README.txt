= RightScale Amazon Web Services Ruby Gems

Published by RightScale, Inc. under the MIT License.
For information about RightScale, see http://www.rightscale.com

== DESCRIPTION:

The RightScale AWS gems have been designed to provide a robust, fast, and secure interface to Amazon EC2, EBS, S3, SQS, SDB, and CloudFront. 
These gems have been used in production by RightScale since late 2006 and are being maintained to track enhancements made by Amazon. 
The RightScale AWS gems comprise:

- RightAws::Ec2 -- interface to Amazon EC2 (Elastic Compute Cloud) and the
  associated EBS (Elastic Block Store)
- RightAws::S3 and RightAws::S3Interface -- interface to Amazon S3 (Simple Storage Service)
- RightAws::Sqs and RightAws::SqsInterface -- interface to first-generation Amazon SQS (Simple Queue Service) (API version 2007-05-01)
- RightAws::SqsGen2 and RightAws::SqsGen2Interface -- interface to second-generation Amazon SQS (Simple Queue Service) (API version 2008-01-01)
- RightAws::SdbInterface and RightAws::ActiveSdb -- interface to Amazon SDB (SimpleDB)
- RightAws::AcfInterface -- interface to Amazon CloudFront, a content distribution service

== FEATURES:

- Full programmmatic access to EC2, EBS, S3, SQS, SDB, and CloudFront.
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
- Support for signature versions 0 and 1 on SQS, SDB, and EC2.
- Interoperability with any cloud running Eucalyptus (http://eucalyptus.cs.ucsb.edu)
- Test suite (requires AWS account to do "live" testing).

== THREADING:

All RightScale AWS interfaces offer two threading options:
1. Use a single persistent HTTP connection per process.
2. Use a persistent HTTP connection per Ruby thread.
 
Either way, it doesn't matter how many (for example) RightAws::S3 objects you create,
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

By default, EC2/S3/SQS/SDB/ACF interface instances are created in single-threaded mode.  Set
"params[:multi_thread]" to "true" in the initialization arguments to use
multithreaded mode.

== GETTING STARTED:

* For EC2 read RightAws::Ec2 and consult the Amazon EC2 API documentation at
  http://developer.amazonwebservices.com/connect/kbcategory.jspa?categoryID=87
* For S3 read RightAws::S3 and consult the Amazon S3 API documentation at
  http://developer.amazonwebservices.com/connect/kbcategory.jspa?categoryID=48
* For first generation SQS read RightAws::Sqs and consult the Amazon SQS API documentation at
  http://developer.amazonwebservices.com/connect/kbcategory.jspa?categoryID=31
* For second generation SQS read RightAws::SqsGen2, RightAws::SqsGen2Interface, and consult the Amazon SQS API documentation at
  http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1214&categoryID=31 

  Amazon's Migration Guide for moving from first to second generation SQS is
  avalable at:
  http://developer.amazonwebservices.com/connect/entry.jspa?externalID=1148
* For SDB read RightAws::SdbInterface, RightAws::ActiveSdb, and consult the Amazon SDB API documentation at
  http://developer.amazonwebservices.com/connect/kbcategory.jspa?categoryID=141
* For CloudFront (ACF) read RightAws::AcfInterface and consult the Amazon CloudFront API documentation at 
  http://developer.amazonwebservices.com/connect/kbcategory.jspa?categoryID=213

== KNOWN ISSUES:

- 7/08: A user has reported that uploads of large files on Windows may be broken on some
  Win platforms due to a buggy File.lstat.size.  Use the following monkey-patch at your own risk, 
  as it has been proven to break Rails 2.0 on Windows:

    require 'win32/file'
    class File
      def lstat
        self.stat
      end
    end


- Attempting to use the Gibberish plugin (used by the Beast forum app) 
  will break right_aws as well as lots of other code.  Gibberish
  changes the semantics of core Ruby (specifically, the String class) and thus presents a reliability
  problem for most Ruby programs.

- 2/11/08: If you use RightAws in conjunction with attachment_fu, the
  right_aws gem must be included (using the require statement) AFTER
  attachment_fu.  If right_aws is loaded before attachment_fu, you'll
  encounter errors similar to:

  s3.amazonaws.com temporarily unavailable: (wrong number of arguments (5 for 4))

  or

  'incompatible Net::HTTP monkey-patch'

  This is due to a conflict between the right_http_connection gem and another
  gem required by attachment_fu.

- 8/07: Amazon has changed the semantics of the SQS service.  A
  new queue may not be created within 60 seconds of the destruction of any
  older queue with the same name.  Certain methods of RightAws::Sqs and
  RightAws::SqsInterface will fail with the message:
  "AWS.SimpleQueueService.QueueDeletedRecently: You must wait 60 seconds after deleting a queue before you can create another with the same name."
  
== REQUIREMENTS:

RightAws requires REXML and the right_http_connection gem.
If libxml and its Ruby bindings (distributed in the libxml-ruby gem) are
present, RightAws can be configured to use them:
  RightAws::RightAWSParser.xml_lib = 'libxml'
Any error with the libxml installation will result in RightAws failing-safe to
REXML parsing.

== INSTALL:

sudo gem install right_aws

== LICENSE:

Copyright (c) 2007-2008 RightScale, Inc. 

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
