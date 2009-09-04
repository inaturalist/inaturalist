$:.unshift(File.join(File.dirname(__FILE__) ,'../../gems/georuby/lib/'))
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

namespace :test do
  Rake::TestTask::new(:mysql => "db:mysql" ) do |t|
    t.test_files = FileList['test/*_mysql_test.rb']
    t.verbose = true
  end

  Rake::TestTask::new(:postgis => "db:postgis" ) do |t|
    t.test_files = FileList['test/*_postgis_test.rb']
    t.verbose = true 
  end
end

namespace :db do
  task :mysql do
    load('test/schema/schema_mysql.rb')
  end

  task :postgis do
    load('test/schema/schema_postgis.rb')
  end
end

desc "Generate the documentation"
Rake::RDocTask::new do |rdoc|
  rdoc.rdoc_dir = 'spatialadapter-doc/'
  rdoc.title    = "MySql Spatial Adapater for Rails Documentation"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
