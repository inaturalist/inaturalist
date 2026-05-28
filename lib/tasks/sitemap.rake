# frozen_string_literal: true

require Rails.root.join( "lib", "sitemap", "generator" )

namespace :sitemap do
  desc "Generate full sitemaps for projects, people, taxa, places, blog posts, journal posts, and project journal posts"
  task generate_all: :environment do
    generator = Sitemap::Generator.new(
      chunk_size: ENV.fetch( "CHUNK_SIZE", nil ),
      batch_size: ENV.fetch( "BATCH_SIZE", nil )
    )
    generator.generate!
  end
end
