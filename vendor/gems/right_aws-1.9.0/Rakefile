# -*- ruby -*-

require 'rubygems'
require 'hoe'
require "rake/testtask"
require 'rcov/rcovtask'
$: << File.dirname(__FILE__)
require 'lib/right_aws.rb'

testglobs =     ["test/ts_right_aws.rb"]


# Suppress Hoe's self-inclusion as a dependency for our Gem.  This also keeps
# Rake & rubyforge out of the dependency list.  Users must manually install
# these gems to run tests, etc.
class Hoe
  def extra_deps
    @extra_deps.reject do |x|
      Array(x).first == 'hoe'
    end
  end
end

Hoe.new('right_aws', RightAws::VERSION::STRING) do |p|
  p.rubyforge_name = 'rightaws'
  p.author = 'RightScale, Inc.'
  p.email = 'support@rightscale.com'
  p.summary = 'Interface classes for the Amazon EC2, SQS, and S3 Web Services'
  p.description = p.paragraphs_of('README.txt', 2..5).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.remote_rdoc_dir = "/right_aws_gem_doc"
  p.extra_deps = [['right_http_connection','>= 1.2.1']]
  p.test_globs = testglobs 
end

desc "Analyze code coverage of the unit tests."
Rcov::RcovTask.new do |t|
  t.test_files = FileList[testglobs]
  #t.verbose = true     # uncomment to see the executed command
end
 
desc "Test just the SQS interface"
task :testsqs do
  require 'test/test_credentials'
  require 'test/http_connection'
  TestCredentials.get_credentials
  require 'test/sqs/test_right_sqs.rb'
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
  require 'test/s3/test_right_s3.rb'
end

desc "Test just the S3 interface using local stubs"
task :tests3local do
  require 'test/test_credentials'
  require 'test/http_connection'
  TestCredentials.get_credentials
  require 'test/s3/test_right_s3_stubbed.rb'
end

desc "Test just the EC2 interface"
task :testec2 do
  require 'test/test_credentials'
  TestCredentials.get_credentials
  require 'test/ec2/test_right_ec2.rb'
end

desc "Test just the SDB interface"
task :testsdb do
  require 'test/test_credentials'
  TestCredentials.get_credentials
  require 'test/sdb/test_right_sdb.rb'
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
  require 'test/acf/test_right_acf.rb'
end

# vim: syntax=Ruby
