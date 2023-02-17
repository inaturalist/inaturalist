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
    List.where(user_id: spammer_ids).destroy_all
    Observation.where(user_id: spammer_ids).destroy_all
    Post.where(user_id: spammer_ids).destroy_all
    Project.where(user_id: spammer_ids).destroy_all
    User.where(id: spammer_ids).update_all(description: nil)
  end

  desc "Delete expired updates"
  task :delete_expired_updates => :environment do
    earliest_id = CONFIG.update_action_rollover_id || 1
    min_id = UpdateAction.where( "id >= ?", earliest_id ).where(["created_at < ?", 3.months.ago]).minimum( :id )
    return unless min_id
    # using an ID clause to limit the number of rows in the query
    last_id_to_delete = UpdateAction.where( ["created_at < ?", 3.months.ago] ).
      where("id >= #{min_id} AND id < #{ min_id + 2000000 }").maximum( :id )
    return unless last_id_to_delete
    UpdateAction.delete_and_purge("id >= #{ min_id } AND id <= #{ last_id_to_delete }")
    # delete anything that may be left in Elasticsearch
    try_and_try_again( Elasticsearch::Transport::Transport::Errors::Conflict, sleep: 1, tries: 10 ) do
      Elasticsearch::Model.client.delete_by_query(index: UpdateAction.index_name,
        body: { query: { range: { id: { gte: min_id, lte: last_id_to_delete } } } })
    end

    # # suspend subscriptions of users with no viewed updates
    # Update.select(:subscriber_id).group(:subscriber_id).having("max(viewed_at) IS NULL").
    #   order(:subscriber_id).pluck(:subscriber_id).each_slice(500) do |batch|
    #   # get this batch's users
    #   users_to_suspend = User.where(id: batch.compact).where(subscriptions_suspended_at: nil)
    #   # send them emails that we're suspending their subscriptions
    #   users_to_suspend.each do |u|
    #     Emailer.user_updates_suspended(u).deliver_now
    #   end
    #   # suspend their subscriptions
    #   User.where(id: users_to_suspend.pluck(:id)).update_all(subscriptions_suspended_at: Time.now)
    # end
  end

  desc "Delete expired S3 photos"
  task :delete_expired_photos => :environment do
    client = LocalPhoto.new.s3_client
    fails = 0
    DeletedPhoto.still_in_s3.
      joins("LEFT JOIN photos ON (deleted_photos.photo_id = photos.id)").
      where("photos.id IS NULL").
      where("(orphan=false AND deleted_photos.created_at <= ?)
        OR (orphan=true AND deleted_photos.created_at <= ?)",
        6.months.ago, 1.month.ago).select(:id, :photo_id).find_each do |dp|
      begin
        dp.remove_from_s3( s3_client: client )
      rescue
        fails += 1
        break if fails >= 5
      end
    end
    # Delete user profile pics for users that were deleted over a month ago
    DeletedUser.where( "created_at < ?", 1.month.ago ).each do |du|
      begin
        User.remove_icon_from_s3( du.user_id )
      rescue
        fails += 1
        break if fails >= 5
      end
    end
  end

  desc "Delete expired local photos"
  task :delete_expired_local_photos => :environment do
    return unless Rails.env.development?
    deleted = []
    DeletedPhoto.find_each do |dp|
      path = File.join( Rails.root, "public", "attachments", "local_photos", "files", dp.photo_id.to_s )
      if File.exists?( path )
        deleted_paths = FileUtils.rm_rf( path )
        if deleted_paths.size > 0
          deleted << dp.photo_id
        end
      end
    end
    puts "Deleted #{deleted.size} expired local photo directories"
  end

  desc "Delete expired S3 sounds"
  task :delete_expired_sounds => :environment do
    S3_CONFIG = YAML.load_file(File.join(Rails.root, "config", "s3.yml"))
    client = ::Aws::S3::Client.new(
      access_key_id: S3_CONFIG["access_key_id"],
      secret_access_key: S3_CONFIG["secret_access_key"],
      region: CONFIG.s3_region
    )

    fails = 0
    DeletedSound.still_in_s3.
      joins("LEFT JOIN sounds ON (deleted_sounds.sound_id = sounds.id)").
      where("sounds.id IS NULL").
      where("(orphan=false AND deleted_sounds.created_at <= ?)
        OR (orphan=true AND deleted_sounds.created_at <= ?)",
        6.months.ago, 1.month.ago).select(:id, :sound_id).find_each do |s|
      sounds = client.list_objects( bucket: CONFIG.s3_bucket, prefix: "sounds/#{ s.sound_id }." ).contents
      if sounds.any?
        pp sounds
        begin
          client.delete_objects( bucket: CONFIG.s3_bucket, delete: { objects: sounds.map{|s| { key: s.key } } } )
          s.update(removed_from_s3: true)
        rescue
          fails += 1
          break if fails >= 5
        end
      end
    end
  end

  desc "Delete orphaned photos"
  task :delete_orphaned_photos => :environment do
    first_id = Photo.minimum(:id)
    last_id = Photo.maximum(:id) - 10000
    index = first_id
    batch_size = 10000
    # using `where id BETWEEN` instead of .find_each or similar, which use
    # LIMIT and create fewer, but longer-running queries
    orphans_count = 0
    last_orphan_id = 0
    while index <= last_id
      photos = Photo.joins("left join observation_photos op on (photos.id=op.photo_id)").
        joins("left join taxon_photos tp on (photos.id=tp.photo_id)").
        joins("left join guide_photos gp on (photos.id=gp.photo_id)").
        where("op.id IS NULL and tp.id IS NULL and gp.id IS NULL").
        where("photos.id BETWEEN ? AND ?", index, index + batch_size).
        where("photos.created_at <= ?", 1.week.ago)
      photos.each do |p|
        # set the orphan attribute on Photo, which will set the same on DeletedPhoto
        begin
          p.orphan = true
          p.destroy
          last_orphan_id = p.id
          orphans_count += 1
        rescue Exception => e
          Rails.logger.error "[ERROR #{Time.now}] Rake task delete_orphaned_photos: #{e}"
        end
      end
      index += batch_size
      puts "#{index} :: total #{orphans_count} :: last #{last_orphan_id}"
    end
  end

  desc "Delete orphaned sounds"
  task :delete_orphaned_sounds => :environment do
    first_id = Sound.minimum(:id)
    last_id = Sound.maximum(:id) - 10000
    index = 0
    batch_size = 10000
    orphans_count = 0
    last_orphan_id = 0
    # using `where id BETWEEN` instead of .find_each or similar, which use
    # LIMIT and create fewer, but longer-running queries
    while index <= last_id
      sounds = Sound.joins("left join observation_sounds os on (sounds.id=os.sound_id)").
        where("os.id IS NULL").
        where("sounds.id BETWEEN ? AND ?", index, index + batch_size).
        where("sounds.created_at <= ?", 1.week.ago)
      sounds.each do |s|
        # set the orphan attribute on sound, which will set the same on Deletedsound
        s.orphan = true
        s.destroy
        last_orphan_id = p.id
        orphans_count += 1
      end
      index += batch_size
      puts "#{index} :: total #{orphans_count} :: last #{last_orphan_id}"
    end
  end


  desc "Delete orphaned and expired photos"
  task :delete_orphaned_and_expired_photos => :environment do
    Rake::Task["inaturalist:delete_orphaned_photos"].invoke
    Rake::Task["inaturalist:delete_expired_photos"].invoke
  end

  desc "Delete orphaned and expired sounds"
  task :delete_orphaned_and_expired_sounds => :environment do
    Rake::Task["inaturalist:delete_orphaned_sounds"].invoke
    Rake::Task["inaturalist:delete_expired_sounds"].invoke
  end

  def get_i18n_keys_in_rb
    all_keys = []
    scanner_proc = Proc.new do |f|
      # Ignore non-files
      next unless File.file?( f )
      # Ignore images and php scripts
      next unless f =~ /\.(rb|erb|haml)$/
      # Ignore an existing translations file
      # next if paths_to_ignore.include?( f )
      contents = File.open( f ).read
      results = contents.scan(/(I18n\.)?t[\(\s]*([\:"'])([A-z_\.\d\?\!]+)/i)
      unless results.empty?
        all_keys += results.map{ |r| r[2].chomp(".") }
      end
    end
    Dir.glob(Rails.root.join("app/controllers/**/*")).each(&scanner_proc)
    Dir.glob(Rails.root.join("app/views/**/*")).each(&scanner_proc)
    Dir.glob(Rails.root.join("app/models/**/*")).each(&scanner_proc)
    Dir.glob(Rails.root.join("app/helpers/**/*")).each(&scanner_proc)
    Dir.glob(Rails.root.join("lib/**/*")).each(&scanner_proc)
    all_keys
  end

  # Returns all keys in dot notation, e.g. views.observations.show.some_text
  def get_i18n_keys_in_js( options = {} )
    paths_to_ignore = ["app/assets/javascripts/i18n/translations.js"]
    # various keys from models, or from JS dynamic calls
    all_keys = [
      "added!",
      "amphibians",
      "animals",
      "arachnids",
      "asc",
      "birds",
      "black",
      "blue",
      "brown",
      "browse",
      "captive_observations",
      "casual",
      "checklist",
      "copyright",
      "data_quality",
      "date.formats.month_day_year",
      "date_added",
      "date_format.month",
      "date_observed",
      "date_observed_",
      "date_picker",
      "date_updated",
      "default_",
      "desc",
      "edit_license",
      "endemic",
      "exporting",
      "find",
      "find",
      "flowering_phenology",
      "frequency",
      "fungi",
      "green",
      "grey",
      "imperiled",
      "inappropriate",
      "input_taxon",
      "insect_life_stage",
      "insects",
      "introduced",
      "kml_file_size_error",
      "lexicons",
      "lexicons",
      "loading",
      "mammals",
      "maps",
      "maptype_for_places",
      "misidentifications",
      "mollusks",
      "momentjs",
      "native",
      "none",
      "number_selected",
      "observation_date",
      "orange",
      "other_species_commonly_misidentified_as_this_species",
      "other_species_commonly_misidentified_as_this_species_in_place_html",
      "other_taxa_commonly_misidentified_as_this_complex",
      "other_taxa_commonly_misidentified_as_this_complex_in_place_html",
      "other_taxa_commonly_misidentified_as_this_genus",
      "other_taxa_commonly_misidentified_as_this_genus_in_place_html",
      "other_taxa_commonly_misidentified_as_this_genushybrid",
      "other_taxa_commonly_misidentified_as_this_genushybrid_in_place_html",
      "other_taxa_commonly_misidentified_as_this_hybrid",
      "other_taxa_commonly_misidentified_as_this_hybrid_in_place_html",
      "other_taxa_commonly_misidentified_as_this_rank",
      "other_taxa_commonly_misidentified_as_this_rank_in_place_html",
      "other_taxa_commonly_misidentified_as_this_section",
      "other_taxa_commonly_misidentified_as_this_section_in_place_html",
      "other_taxa_commonly_misidentified_as_this_species",
      "other_taxa_commonly_misidentified_as_this_species_in_place_html",
      "other_taxa_commonly_misidentified_as_this_subgenus",
      "other_taxa_commonly_misidentified_as_this_subgenus_in_place_html",
      "other_taxa_commonly_misidentified_as_this_subsection",
      "other_taxa_commonly_misidentified_as_this_subsection_in_place_html",
      "output_taxon",
      "pink",
      "place_geo.geo_planet_place_types",
      "places_name",
      "places_name",
      "plants",
      "preview",
      "protozoans",
      "purple",
      "random",
      "ranks",
      "ranks_lowercase_stateofmatter",
      "ranks_lowercase_kingdom",
      "ranks_lowercase_subkingdom",
      "ranks_lowercase_phylum",
      "ranks_lowercase_subphylum",
      "ranks_lowercase_superclass",
      "ranks_lowercase_class",
      "ranks_lowercase_subclass",
      "ranks_lowercase_infraclass",
      "ranks_lowercase_superorder",
      "ranks_lowercase_order",
      "ranks_lowercase_suborder",
      "ranks_lowercase_infraorder",
      "ranks_lowercase_subterclass",
      "ranks_lowercase_parvorder",
      "ranks_lowercase_zoosection",
      "ranks_lowercase_zoosubsection",
      "ranks_lowercase_superfamily",
      "ranks_lowercase_epifamily",
      "ranks_lowercase_family",
      "ranks_lowercase_subfamily",
      "ranks_lowercase_supertribe",
      "ranks_lowercase_tribe",
      "ranks_lowercase_subtribe",
      "ranks_lowercase_genus",
      "ranks_lowercase_genushybrid",
      "ranks_lowercase_subgenus",
      "ranks_lowercase_section",
      "ranks_lowercase_subsection",
      "ranks_lowercase_complex",
      "ranks_lowercase_species",
      "ranks_lowercase_hybrid",
      "ranks_lowercase_subspecies",
      "ranks_lowercase_variety",
      "ranks_lowercase_form",
      "ranks_lowercase_infrahybrid",
      "ray_finned_fishes",
      "red",
      "reload_timed_out",
      "reptiles",
      "research",
      "rg_observations",
      "saving",
      "something_went_wrong_adding",
      "status_globally",
      "status_in_place",
      "subscribe_to_observations_from_this_place_html",
      "supporting",
      "taxon_drop",
      "taxon_merge",
      "taxon_split",
      "taxon_stage",
      "taxon_swap",
      "unknown",
      "view_more",
      "views.observations.export.taking_a_while",
      "views.taxa.show.frequency",
      "white",
      "vulnerable",
      "yellow",
      "you_are_setting_this_project_to_aggregate",
      "i18n.inflections.@gender",
      "i18n.inflections.@vow_or_con"
    ]
    %w(
      all_rank_added_to_the_database
      all_taxa
      controlled_term_labels
      controlled_term_definitions
      establishment
      locales
    ).each do |key|
      all_keys += I18n.t( key ).map{|k,v| "#{key}.#{k}" }
    end
    all_keys += ControlledTerm.attributes.map{|a|
      a.values.map{|v| "add_#{a.label.parameterize.underscore}_#{v.label.parameterize.underscore}_annotation" }
    }.flatten
    # look for other keys in all javascript files
    scanner_proc = Proc.new do |f|
      # Ignore non-files
      next unless File.file?( f )
      # Ignore images and php scripts
      next if f =~ /\.(gif|png|php)$/
      # Ignore generated webpack outputs
      next if f =~ /\-webpack.js$/
      # Ignore an existing translations file
      next if paths_to_ignore.include?( f )
      contents = File.open( f ).read
      results = contents.scan(/(I18n|shared|inatreact).t\(\s*(["'])(.*?)\2/i)
      unless results.empty?
        all_keys += results.map{ |r| r[2].chomp(".") }.select{|k| k =~ /^[A-z]/ }
      end
    end
    Dir.glob(Rails.root.join("app/assets/javascripts/**/*")).each(&scanner_proc)
    Dir.glob(Rails.root.join("app/webpack/**/*")).each(&scanner_proc)

    # look for keys in angular expressions in all templates
    Dir.glob(Rails.root.join("app/views/**/*")).each do |f|
      next unless File.file?( f )
      next if f =~ /\.(gif|png|php)$/
      next if paths_to_ignore.include?( f )
      contents = File.open( f ).read
      results = contents.scan(/\{\{.*?(I18n|shared).t\( ?(.)(.*?)\2.*?\}\}/i)
      # TODO make this work for I18n.l, I18n.localize, I18n.translate
      unless results.empty?
        all_keys += results.map{ |r| r[2].chomp(".") }.select{|k| k =~ /^[A-z]/ }
      end
    end

    # remnant from a dynamic JS call for colors
    all_keys.delete("lts[i].valu")
    all_keys
  end

  desc "Find all javascript i18n keys and print a new translations.js"
  task :generate_translations_js => :environment do
    output_path = "app/assets/javascripts/i18n/translations.js"
    all_keys = get_i18n_keys_in_js.uniq.sort

    # load translations
    all_translations = { }
    I18n.backend.send(:init_translations)
    I18N_SUPPORTED_LOCALES.each do |locale|
      locale = locale.to_sym
      next if locale === :qqq
      all_translations[ locale ] = { }
      all_keys.each do |key_string|
        split_keys = key_string.split(".").select{|k| k !~ /\#\{/ }.map(&:to_sym)
        split_keys.inject(all_translations[ locale ]) do |h, key|
          if key == split_keys.last
            value = split_keys.inject(I18n.backend.send(:translations)[locale], :[]) rescue nil
            if value
              h[key] ||= value
            elsif Rails.env.development?
              puts "WARNING: Failed to translate #{locale}.#{key}"
            end
          elsif h[key].is_a?( String )
            raise "Expected a nested object but got a string. You probably have a typo in this translation string: #{split_keys.join( "." )}"
          else
            h[key] ||= { }
          end
          h[key]
        end
      end
    end

    # Make a JS file for translations in each locale
    all_translations.sort.each do |locale, translations|
      locale_file_path = "app/assets/javascripts/i18n/translations/#{locale}.js"
      File.open( locale_file_path, "w" ) do |file|
        file.puts "I18n.translations || (I18n.translations = {});"
        file.puts "I18n.translations[\"#{ locale }\"] = #{ JSON.pretty_generate( translations ) };"
        # Add translations for each locale name translated into that locale's
        # language so we can show language pickers that show the language
        # translated into that language
        all_translations.each do |locale_name_locale, locale_name_translations|
          next if locale_name_locale == locale
          file.puts "I18n.translations[\"#{locale_name_locale}\"] = I18n.translations[\"#{locale_name_locale}\"] || {};"
          json = JSON.pretty_generate( locale_name_translations[:locales].select{ |k,v|
            k == locale_name_locale
          } )
          file.puts "I18n.translations[\"#{locale_name_locale}\"][\"locales\"] = #{json};"
        end
      end
    end
  end

  desc <<-EOT
    Print a list of i18n keys in en.yml that don't seem to be used in our JS or
    Ruby code. This will yield some false positives for keys that get
    dynamically constructed in code, so be sure to double check on things before
    deleting.
  EOT
  task :potentially_unused_i18n_keys => :environment do
    patterns_to_ignore = [
      # Keys scoped with dots tend to come from third parties like momentjs or
      # are intended to be dynamically generated, so I'm ignoring them here.
      # There are almost certainly some view-specific keys that will get
      # incorrectly omitted by this
      /\./,
      /^add_life_stage_/,
      /^add_alive_or_dead_/,
      /^add_plant_phenology_/,
      /^add_sex_/,
      /^admin$/,
      /^alphabetical$/,
      /^are_you_sure_want_delete_taxon/,
      /^cc_/,
      /^curator$/,
      /^Family/,
      /^flag_for_/,
      /^Genus/,
      /^header_your_/,
      /^inbox$/,
      /^inviteonly$/,
      /^large$/,
      /^listed_taxa$/,
      /^manager$/,
      /^medium$/,
      /^mentioned_you_in_/,
      /^message_from_user_/,
      /^most_agree$/,
      /^most_disagree$/,
      /^network_affiliation_prompt_from_inat_to_inaturalist_suomi_html/,
      /^observation_field_type_/,
      /^open$/,
      /^other_taxa_commonly_misidentified_as_this_/,
      /^original$/,
      /^sent$/,
      /^simple$/,
      /^small$/,
      /^some_agree$/,
      /^subscribe_to_comments_on_this_/,
      /^taxon_is_a_rank_of_.*/,
      /^taxonomic$/,
      /^user_added_a/,
      /^you_are_subscribed_to_/,
    ]
    model_name_patterns = Dir.glob( File.join( Rails.root, "app", "models", "*.rb" ) ).map do |path|
      /^#{File.basename( path ).split(".")[0]}$/
    end
    patterns_to_ignore += model_name_patterns
    all_keys_in_use = (get_i18n_keys_in_js + get_i18n_keys_in_rb).uniq

    def traverse(obj, branch = nil, &blk)
      if obj.is_a?( Hash )
        obj.each do |k,v|
          if v.is_a?( Hash )
            if v.keys.include?( :one ) || v.keys.include?( "one" )
              blk.call( k, branch )
            else
              traverse(v, [branch, k].flatten.compact.join( "." ), &blk)
            end
          else
            blk.call( k, branch )
          end
        end
      else
        blk.call( obj, branch )
      end
    end

    all_keys = []
    traverse( YAML.load_file( File.join( Rails.root, "config", "locales", "en.yml" ) ) ) do |str, branch|
      key = "#{branch}.#{str}".sub( /^en\./, "" )
      next if patterns_to_ignore.detect{|p| key =~ p }
      all_keys << key
    end
    ( all_keys - all_keys_in_use ).sort.each do |key|
      puts key
    end
  end

  desc "Remove expired sessions"
  task :remove_expired_sessions => :environment do
    expiration_date = 7.days.ago
    ActiveRecord::SessionStore::Session.select(:id, :updated_at).find_in_batches(batch_size: 10000) do |batch|
      expired_ids = batch.select{ |s| s.updated_at < expiration_date }.map(&:id)
      ActiveRecord::SessionStore::Session.where(id: expired_ids).delete_all
    end
  end

end
