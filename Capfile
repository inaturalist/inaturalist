load 'deploy' if respond_to?(:namespace) # cap2 differentiator
load 'config/deploy'

task :bork do
  puts "DEBUG: deploy_to: #{deploy_to}"
end

namespace :deploy do
  
  desc "Create shared directories and copy example files"
  task :install_app do
    copy_config
    copy_db_config
    copy_gmap_api_key
    copy_smtp_config
    create_attachments
    create_cache
    copy_sphinx
    copy_geoip_config
  end

  task :after_update do
    symlink_config
    symlink_db_config
    symlink_gmap_api_key
    symlink_smtp_config
    symlink_geoip_config
    symlink_attachments
    symlink_cache
    symlink_sphinx
    sphinx_configure
  end
  
  task :after_restart do
    cleanup
    sphinx_restart
    chgrp_to_user
  end

  desc "Create a symlink to a copy of config.yml that is outside the repos."
  task :symlink_config, :hosts => "#{domain}" do
    run "ln -s #{inat_config_shared_path}/config.yml #{latest_release}/config/config.yml"
  end

  desc "Create a symlink to a copy of database.yml that is outside the repos."
  task :symlink_db_config, :hosts => "#{domain}" do
    run "ln -s #{inat_config_shared_path}/database.yml #{latest_release}/config/database.yml"
  end
  
  desc "Create a symlink to domain, dev.domain or test.domain gmap_api_key.yml file"
  task :symlink_gmap_api_key, :hosts => "#{domain}" do
    stage = fetch(:stage, 'production')
    case stage
    when 'test'
      run "ln -s #{inat_config_shared_path}/test_gmaps_api_key.yml #{latest_release}/config/gmaps_api_key.yml"
    when 'dev', 'development'
      run "ln -s #{inat_config_shared_path}/dev_gmaps_api_key.yml #{latest_release}/config/gmaps_api_key.yml"
    else
      run "ln -s #{inat_config_shared_path}/production_gmaps_api_key.yml #{latest_release}/config/gmaps_api_key.yml"
    end
  end
  
  desc "Create a symlink to a copy of smtp.yml that is outside the repos."
  task :symlink_smtp_config, :hosts => "#{domain}" do
    run "ln -s #{inat_config_shared_path}/smtp.yml #{latest_release}/config/smtp.yml"
  end
  
  desc "Create a symlink to a copy of geoip.yml that is outside the repos."
  task :symlink_geoip_config, :hosts => "#{domain}" do
    run "ln -s #{inat_config_shared_path}/geoip.yml #{latest_release}/config/geoip.yml"
  end
  
  desc "Symlink to the common attachments dir"
  task :symlink_attachments, :hosts => "#{domain}" do
    run "ln -s #{shared_path}/system/attachments #{latest_release}/public/attachments"
  end
  
  desc "Symlink to the common cache dir"
  task :symlink_cache, :hosts => "#{domain}" do
    run "ln -s #{shared_path}/system/cache #{latest_release}/cache"
    run "ln -s #{shared_path}/system/page_cache/observations #{latest_release}/public/observations"
  end
  
  desc "Clear the cache directories"
  task :clear_cache, :hosts => "#{domain}" do
    run "rm -rf #{shared_path}/system/cache/*"
    run "rm -rf #{shared_path}/system/page_cache/observations/*"
  end
  
  desc "Change group on all files and grant group read & write permissions."
  task :chgrp_to_user, :hosts => "#{domain}" do
    run "chgrp -R #{user} #{latest_release}/*"
    run "chmod -R g+ws #{latest_release}/*"
    # run "chmod g+ws #{deploy_to}/shared/pids/*"
  end
  
  # custom version of web:disable that renders the template in
  # app/views/layouts/maintenance.rhtml instead of the default
  # From http://clarkware.com/cgi/blosxom/2007/01/05#CustomMaintenancePages
  desc "Present a CUSTOM maintenance page to visitors"
  task :disable_web, :roles => :web do
    on_rollback { delete "#{shared_path}/system/maintenance.html" }

    template = File.read("./app/views/layouts/maintenance.rhtml")
    reason = ENV['REASON']
    deadline = ENV['UNTIL']
    maintenance = ERB.new(template).result(binding)

    put maintenance, "#{shared_path}/system/maintenance.html", 
                     :mode => 0644
  end
  
  # added for Passenger
  desc "Restart Application"
  task :restart, :roles => :app do
    run "touch #{latest_release}/tmp/restart.txt"
    # See http://www.modrails.com/documentation/Users%20guide.html#capistrano for info on why this is here
    # won't work for now because inaturalist is not a sudoer
    # run "kill $( passenger-memory-stats | grep 'Passenger spawn server' | awk '{ print $1 }' )"
  end
  
  
  ## SPHINX TASKS ##########################################################
  desc "Symlink path to Sphinx indexes"
  task :symlink_sphinx, :hosts => "#{domain}" do
    run "ln -s #{shared_path}/system/db/sphinx #{latest_release}/db/sphinx"
  end
  
  task :sphinx_start do
    run "cd #{latest_release} && rake thinking_sphinx:start RAILS_ENV=production"
  end
  
  desc "Executes rake thinking_sphinx:stop, which stops the searchd daemon"
  task :sphinx_stop do
    run "cd #{latest_release} && rake thinking_sphinx:stop RAILS_ENV=production"
  end
  
  desc "Restarts the searchd daemon"
  task :sphinx_restart do
    sphinx_stop
    sphinx_start
  end
  
  desc "Executes rake thinking_sphinx:index, which generates the indexes"
  task :sphinx_index do
    run "cd #{latest_release} && rake thinking_sphinx:index RAILS_ENV=production"
  end
  
  desc "Executes rake thinking_sphinx:configure, which builds the Sphinx conf file without re-indexing"
  task :sphinx_configure do
    run "cd #{latest_release} && rake thinking_sphinx:configure RAILS_ENV=production"
  end

  ## INITIAL SETUP ##########################################################

  desc "Copy config file to shared path if not exists"
  task :copy_config, :hosts => "#{domain}" do
    run "test -e #{inat_config_shared_path}/config.yml || cp #{latest_release}/config/config.yml.example #{inat_config_shared_path}/config.yml"
  end

  desc "Copy db config file to shared path if not exists"
  task :copy_db_config, :hosts => "#{domain}" do
    run "test -e #{inat_config_shared_path}/database.yml || cp #{latest_release}/config/database.yml.example #{inat_config_shared_path}/database.yml"
  end
  
  desc "Copy gmap key file to shared path if not exists"
  task :copy_gmap_api_key, :hosts => "#{domain}" do
    stage = fetch(:stage, 'production')
    case stage
    when 'test'
	  run "test -e #{inat_config_shared_path}/test_gmaps_api_key.yml || cp #{latest_release}/config/gmaps_api_key.yml.example #{inat_config_shared_path}/config/gmaps_api_key.yml"
    when 'dev', 'development'
      run "test -e #{inat_config_shared_path}/dev_gmaps_api_key.yml || cp #{latest_release}/config/gmaps_api_key.yml.example #{inat_config_shared_path}/dev_gmaps_api_key.yml"
    else
	  run "test -e #{inat_config_shared_path}/production_gmaps_api_key.yml || cp #{latest_release}/config/gmaps_api_key.yml.example #{inat_config_shared_path}/production_gmaps_api_key.yml"
    end
  end
  
  desc "Copy smtp.yml.example if not exists"
  task :copy_smtp_config, :hosts => "#{domain}" do
    run "test -e #{inat_config_shared_path}/smtp.yml || cp #{latest_release}/config/smtp.yml.example #{inat_config_shared_path}/smtp.yml"
  end
  
  desc "Create to the common attachments dir"
  task :create_attachments, :hosts => "#{domain}" do
    run "test -d #{shared_path}/system/attachments || mkdir #{shared_path}/system/attachments"
  end
  
  desc "Create the common cache dir"
  task :create_cache, :hosts => "#{domain}" do
    run "test -d #{shared_path}/system/cache || mkdir #{shared_path}/system/cache"
    run "test -d #{shared_path}/system/page_cache || mkdir #{shared_path}/system/page_cache"
    run "test -d #{shared_path}/system/page_cache/observations || mkdir #{shared_path}/system/page_cache/observations"
  end
  
  desc "copy dir for Sphinx indexes"
  task :copy_sphinx, :hosts => "#{domain}" do
    run "test -d #{shared_path}/system/db || mkdir #{shared_path}/system/db"
    run "test -d #{shared_path}/system/db/sphinx || mkdir #{shared_path}/system/db/sphinx"
  end

  desc "Copy geoip.yml.example to shared directory as geoip.yml if not exists"
  task :copy_geoip_config, :hosts => "#{domain}" do
    run "test -e #{inat_config_shared_path}/geoip.yml || cp #{latest_release}/config/geoip.yml.example #{inat_config_shared_path}/geoip.yml"
  end

end
