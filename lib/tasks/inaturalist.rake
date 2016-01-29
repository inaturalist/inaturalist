namespace :inaturalist do
  desc "Copy example config files."
  task :setup do
    Dir.glob("#{Rails.root}/config/*.example").each do |file|
      example = File.basename(file)
      file = File.basename(example, '.example')
      if File.exists?(Rails.root.join('config', file))
        puts "#{file} already exists."
      else
        cp Rails.root.join('config', example), Rails.root.join('config', file)
      end
    end
    exit 0
  end

  desc "Set the public_positional_accuracy and mappable fields on observations."
  task :update_public_accuracy => :environment do
    batch = 0
    batch_size = 10000
    total_observations = Observation.count
    total_batches = (total_observations / batch_size).ceil
    start_time = Time.now
    Observation.includes(:quality_metrics).find_in_batches(batch_size: batch_size) do |observations|
      puts "Starting batch #{ batch += 1 } of #{ total_batches } at #{ (Time.now - start_time).round(2) } seconds"
      Observation.connection.transaction do
        observations.each do |o|
          o.update_public_positional_accuracy
          o.update_mappable
        end
      end
    end
  end

  desc "Delete content from spmmer accounts."
  task :delete_spam_content => :environment do
    spammer_ids = User.where(spammer: true).
      where("suspended_at < ?", User::DELETE_SPAM_AFTER.ago).
      collect(&:id)
    Comment.where(user_id: spammer_ids).destroy_all
    Guide.where(user_id: spammer_ids).destroy_all
    Identification.where(user_id: spammer_ids).destroy_all
    List.where(user_id: spammer_ids).where("lists.type != 'LifeList'").destroy_all
    Observation.where(user_id: spammer_ids).destroy_all
    Post.where(user_id: spammer_ids).destroy_all
    Project.where(user_id: spammer_ids).destroy_all
    User.where(id: spammer_ids).update_all(description: nil)
  end

  desc "Delete expired updates"
  task :delete_expired_updates => :environment do
    min_id = Update.minimum(:id)
    # using an ID clause to limit the number of rows in the query
    last_id_to_delete = Update.where(["created_at < ?", 3.months.ago]).
      where("id < #{ min_id + 1000000 }").maximum(:id)
    Update.delete_and_purge("id <= #{ last_id_to_delete }")
    # delete anything that may be left in Elasticsearch
    Elasticsearch::Model.client.delete_by_query(index: Update.index_name,
      body: { query: { range: { id: { lte: last_id_to_delete } } } })

    # suspend subscriptions of users with no viewed updates
    Update.select(:subscriber_id).group(:subscriber_id).having("max(viewed_at) IS NULL").
      order(:subscriber_id).pluck(:subscriber_id).each_slice(500) do |batch|
      # get this batch's users
      users_to_suspend = User.where(id: batch.compact).where(subscriptions_suspended_at: nil)
      # send them emails that we're suspending their subscriptions
      users_to_suspend.each do |u|
        Emailer.user_updates_suspended(u).deliver_now
      end
      # suspend their subscriptions
      User.where(id: users_to_suspend.pluck(:id)).update_all(subscriptions_suspended_at: Time.now)
    end
  end

  desc "Delete expired S3 photos"
  task :delete_expired_photos => :environment do
    S3_CONFIG = YAML.load_file(File.join(Rails.root, "config", "s3.yml"))
    AWS.config(access_key_id: S3_CONFIG["access_key_id"],
      secret_access_key: S3_CONFIG["secret_access_key"], region: "us-east-1")
    bucket = AWS::S3.new.buckets[CONFIG.s3_bucket]

    DeletedPhoto.where("created_at >= ?", 6.months.ago).
      select(:id, :photo_id).find_each do |p|
      images = bucket.objects.with_prefix("photos/#{ p.photo_id }/").to_a
      if images.any?
        bucket.objects.delete(images)
      end
    end
  end

  desc "Find all javascript i18n keys and print a new translations.js"
  task :generate_translations_js => :environment do
    output_path = "app/assets/javascripts/i18n/translations.js"
    # various keys from models, or from JS dynamic calls
    all_keys = [ "black", "white", "red", "green", "blue", "purple",
                 "yellow", "grey", "orange", "brown", "pink",
                 "preview", "browse", "view_more", "added!", "find",
                 "reload_timed_out", "something_went_wrong_adding",
                 "exporting", "loading", "saving", "find", "none",
                 "colors", "maptype_for_places", "edit_license",
                 "kml_file_size_error", "input_taxon", "output_taxon",
                 "date_added", "observation_date", "date_picker",
                 "views.observations.export.taking_a_while",
                 "place_geo.geo_planet_place_types",
                 "ranks", "research", "asc", "desc",
                 "date_format.month", "momentjs", "endemic", "native", 
                 "introduced", "casual", "status_globally", "status_in_place",
                 "number_selected",
                 "all_taxa.animals",
                 "all_taxa.birds",
                 "all_taxa.amphibians",
                 "all_taxa.reptiles",
                 "all_taxa.mammals",
                 "all_taxa.insects",
                 "all_taxa.arachnids",
                 "all_taxa.mollusks",
                 "all_taxa.ray_finned_fishes",
                 "all_taxa.plants",
                 "all_taxa.fungi",
                 "all_taxa.protozoans" ]

    # look for other keys in all javascript files
    Dir.glob(Rails.root.join("app/assets/javascripts/**/*")).each do |f|
      next unless File.file?( f )
      next if f =~ /\.(gif|png|php)$/
      next if f == output_path
      contents = IO.read( f )
      results = contents.scan(/(I18n|shared).t\( ?(.)(.*?)\2/i)
      unless results.empty?
        all_keys += results.map{ |r| r[2].chomp(".") }
      end
    end

    # look for keys in angular expressions in all templates
    Dir.glob(Rails.root.join("app/views/**/*")).each do |f|
      next unless File.file?( f )
      next if f =~ /\.(gif|png|php)$/
      next if f == output_path
      contents = IO.read( f )
      results = contents.scan(/\{\{.*?(I18n|shared).t\( ?(.)(.*?)\2.*?\}\}/i)
      unless results.empty?
        all_keys += results.map{ |r| r[2].chomp(".") }
      end
    end

    # remnant from a dynamic JS call for colors
    all_keys.delete("lts[i].valu")

    # load translations
    all_translations = { }
    I18n.backend.send(:init_translations)
    I18n.backend.send(:translations).keys.each do |locale|
      next if locale === :qqq
      all_translations[ locale ] = { }
      all_keys.uniq.sort.each do |key_string|
        split_keys = key_string.split(".").select{|k| k !~ /\#\{/ }.map(&:to_sym)
        var = split_keys.inject(all_translations[ locale ]) do |h, key|
          if key == split_keys.last
            # fallback to English if there is no translation in the specified locale
            value = split_keys.inject(I18n.backend.send(:translations)[locale], :[]) rescue nil
            value ||= split_keys.inject(I18n.backend.send(:translations)[:en], :[]) rescue nil
            if value
              h[key] ||= value
            elsif Rails.env.development?
              puts "WARNING: Failed to translate #{key}"
            end
          else
            h[key] ||= { }
          end
          h[key]
        end
      end
    end

    # output what should be the new contents of app/assets/javascripts/i18n/translations.js
    File.open(output_path, "w") do |file|
      file.puts "I18n.translations || (I18n.translations = {});"
      all_translations.sort.each do |locale, translastions|
        file.puts "I18n.translations[\"#{ locale }\"] = #{ translastions.to_json };"
      end
    end
  end

  desc "Fetch missing image dimensions"
  task :fetch_image_dimensions => :environment do
    scope = LocalPhoto.where("original_url IS NOT NULL").
      where("metadata IS NULL OR metadata !~ 'dimensions: *\n *:orig'")
    batch_num = 0
    batch_size = 100
    total_batches = (scope.count / batch_size.to_f).ceil
    scope.find_in_batches(batch_size: batch_size) do |batch|
      batch_num += 1
      puts "batch #{ batch_num } of #{ total_batches }"
      batch.each do |photo|
        photo.metadata ||= { }
        photo.metadata[:dimensions] = photo.extrapolate_dimensions_from_original
        photo.update_column(:metadata, photo.metadata)
      end
    end
  end
end
