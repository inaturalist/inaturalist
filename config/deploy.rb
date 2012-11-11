default_run_options[:pty] = true

set :application, "inaturalist"
set :domain,      "inaturalist.org"
default_run_options[:pty] = true
set :repository,  "git@github.com:inaturalist/inaturalist.git"
set :scm, "git"
set :user, "inaturalist"
set :branch, "master"
set :deploy_via, :remote_cache

# Don't use sudo, execute all commands as inaturalist
set :use_sudo, false
set :user, "inaturalist"

# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location
# via the :deploy_to variable:
# set :deploy_to, "~/test_cap_deploy/#{application}"
stage = fetch(:stage, 'production')
case stage
when 'test'
  set :deploy_to, "/home/#{application}/deployment/test/"
  set :port_num, 9001
when 'dev', 'development'
  set :deploy_to, "/home/#{application}/deployment/development/"
  set :port_num, 9002
else
  set :deploy_to, "/home/#{application}/deployment/production/"
  set :port_num, 9000  
end

set :inat_config_shared_path, "#{deploy_to}.."

set :num_listeners, 1

role :app, domain
role :web, domain
role :db,  domain, :primary => true

set :rvm_ruby_string, 'default'
set :rvm_type, :system

# Dir[File.join(File.dirname(__FILE__), '..', 'vendor', 'gems')].each do |vendored_notifier|
#   $: << File.join(vendored_notifier, 'lib')
# end

require './config/boot'
require 'airbrake/capistrano'
require "rvm/capistrano"

set :bundle_flags,    "--deployment"
require "bundler/capistrano"

set :whenever_command, "bundle exec whenever"
require "whenever/capistrano"
