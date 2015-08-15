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
    Update.delete_and_purge(["created_at < ?", 6.months.ago])
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
                 'ranks.kingdom',
                 'ranks.phylum',
                 'ranks.subphylum',
                 'ranks.superclass',
                 'ranks.class',
                 'ranks.subclass',
                 'ranks.superorder',
                 'ranks.order',
                 'ranks.suborder',
                 'ranks.superfamily',
                 'ranks.family',
                 'ranks.subfamily',
                 'ranks.supertribe',
                 'ranks.tribe',
                 'ranks.subtribe',
                 'ranks.genus',
                 'ranks.genushybrid: Géner',
                 'ranks.species',
                 'ranks.hybrid',
                 'ranks.subspecies',
                 'ranks.variety',
                 'ranks.form',
                 'ranks.leaves'
                ]
    # look for other keys in all javascript files
    Dir.glob(Rails.root.join("app/assets/javascripts/**/*")).each do |f|
      next unless File.file?( f )
      next if f =~ /\.(gif|png|php)$/
      next if f == output_path
      contents = IO.read( f )
      results = contents.scan(/I18n.t\((.)(.*?)\1/i)
      unless results.empty?
        all_keys += results.map{ |r| r[1].chomp(".") }
      end
    end
    # remnant from a dynamic JS call for colors
    all_keys.delete("lts[i].valu")
    all_translations = { }
    # load translations
    I18n.backend.send(:init_translations)
    I18n.backend.send(:translations).keys.each do |locale|
      next if locale === :qqq
      all_translations[ locale ] = { }
      all_keys.uniq.sort.each do |key_string|
        split_keys = key_string.split(".").map(&:to_sym)
        var = split_keys.inject(all_translations[ locale ]) do |h, key|
          if key == split_keys.last
            # fallback to English if there is no translation in the specified locale
            value = split_keys.inject(I18n.backend.send(:translations)[locale], :[]) rescue nil
            value ||= split_keys.inject(I18n.backend.send(:translations)[:en], :[])
            h[key] ||= value
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
      all_translations.each do |locale, translastions|
        file.puts "I18n.translations[\"#{ locale }\"] = #{ translastions.to_json };"
      end
    end
  end
end
