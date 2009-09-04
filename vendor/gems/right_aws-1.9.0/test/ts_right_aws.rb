require 'test/unit'
$: << File.dirname(__FILE__)
require 'test_credentials'
TestCredentials.get_credentials

require 'http_connection'
require 'awsbase/test_right_awsbase.rb'
require 'ec2/test_right_ec2.rb'
require 's3/test_right_s3.rb'
require 's3/test_right_s3_stubbed.rb'
require 'sqs/test_right_sqs.rb'
require 'sqs/test_right_sqs_gen2.rb'
require 'sdb/test_right_sdb.rb'
require 'acf/test_right_acf.rb'
