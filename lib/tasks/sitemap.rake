# frozen_string_literal: true

require Rails.root.join( "lib", "sitemap", "sitemap_www_sitemap_generator" )
require Rails.root.join( "lib", "sitemap", "sitemap_partner_sitemap_generator" )

namespace :sitemap do
  desc "Generate full www sitemaps for projects, people, taxa, places, blog posts, and journal posts"
  task :generate_www_sitemap, [:log_task_name] => :environment do | _, args |
    log_task_name = args[:log_task_name]
    task_logger = log_task_name ? TaskLogger.new( log_task_name, nil, "sync" ) : nil
    task_logger&.start
    Sitemap::SitemapWwwSitemapGenerator.new(
      chunk_size: ENV.fetch( "CHUNK_SIZE", nil ),
      batch_size: ENV.fetch( "BATCH_SIZE", nil )
    ).generate!
    task_logger&.end
  end

  desc "Generate partner sitemap XML files in public/sitemap-partners"
  task :generate_partner_sitemaps, [:log_task_name] => :environment do | _, args |
    log_task_name = args[:log_task_name]
    task_logger = log_task_name ? TaskLogger.new( log_task_name, nil, "sync" ) : nil
    task_logger&.start
    Sitemap::SitemapPartnerSitemapGenerator.new.generate!
    task_logger&.end
  end
end
