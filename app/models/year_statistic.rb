# frozen_string_literal: true

class YearStatistic < ApplicationRecord
  belongs_to :user
  belongs_to :site

  has_many :year_statistic_localized_shareable_images, dependent: :destroy

  NUM_ES_WORKERS = [1, ( CONFIG.elasticsearch_hosts&.size || 2 ) - 1].max

  if CONFIG.usingS3
    has_attached_file :shareable_image,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "year_statistics/:id-share.:content_type_extension",
      url: ":s3_alias_url"
    invalidate_cloudfront_caches :shareable_image, "year_statistics/:id-*"
  else
    has_attached_file :shareable_image,
      path: ":rails_root/public/attachments/:class/:id-share.:content_type_extension",
      url: "/attachments/:class/:id-share.:content_type_extension"
  end

  validates_attachment_content_type :shareable_image,
    content_type: [/jpe?g/i, /png/i, /gif/i, /octet-stream/],
    message: "must be JPG, PNG, or GIF"

  # Generates stats for all of iNat for a single year
  def self.generate_for_year( year, options = {} )
    year_statistic = YearStatistic.where( year: year ).where( "user_id IS NULL" )
    year_statistic = if options[:site]
      year_statistic.where( site_id: options[:site] )
    else
      year_statistic.where( "site_id IS NULL" )
    end
    year_statistic = year_statistic.first_or_create
    json = {
      observations: {
        quality_grade_counts: obervation_counts_by_quality_grade( year, options ),
        month_histogram: observations_histogram( year, options.merge( interval: "month", d1: "1908-01-01" ) ),
        week_histogram: observations_histogram( year, options.merge( interval: "week" ) ),
        day_histogram: observations_histogram( year, options.merge( interval: "day" ) ),
        day_last_year_histogram: observations_histogram( year - 1, options.merge( interval: "day" ) ),
        popular: popular_observations( year, options )
      },
      identifications: {
        category_counts: identification_counts_by_category( year, options ),
        month_histogram: identifications_histogram( year, options.merge( interval: "month" ) ),
        week_histogram: identifications_histogram( year, options.merge( interval: "week" ) ),
        day_histogram: identifications_histogram( year, options.merge( interval: "day" ) )
      },
      taxa: {
        leaf_taxa_count: leaf_taxa_count( year, options ),
        iconic_taxa_counts: iconic_taxa_counts( year, options ),
        accumulation: observed_species_accumulation(
          {
            site: options[:site],
            verifiable: true
          },
          options
        )
      },
      users: {
        obs_and_id_activity_counts: obs_and_id_activity_counts( year, options )
      },
      growth: {
        observations: observations_histogram_by_created_month( options ),
        users: users_histogram_by_created_month( options )
      },
      translators: translators( year, options )
    }
    if options[:site].blank?
      json[:publications] = publications( year, options )
      json[:growth][:countries] = observation_counts_by_country( year, options )
      if year < 2021
        json[:budget] = {
          donors: donors( year, options )
        }
      end
      json[:pull_requests] = github_pull_requests( year, options )
      if year >= 2022
        json[:budget] ||= {}
        json[:budget][:monthly_supporters] = monthly_supporters( year, options )
      end
    end
    year_statistic.update( data: json )
    year_statistic.generate_shareable_image( options )

    # Streaks are the longest-running and most memory intensive piece to
    # calculate, and are probably not sustainable for the whole site in the
    # long term. In 2021, it doesn't seem like any available production
    # machine has enough memory to do it for all users. Putting it here
    # ensures that everything else gets calculated first, and if streaks
    # fail, they don't take down everything else. They're also pretty boring
    # as of 2021 since it's basically just a lot of people on year+ long
    # streaks. Yet another thing I never should have built...

    # 2022 update: we decided to just not do streaks on global or site YIR
    # anymore b/c it's too much of a support headache and encourages
    # competetive behavior
    if year <= 2021
      json[:observations][:streaks] = streaks( year, options )
      year_statistic.update( data: json )
    end
    year_statistic
  end

  # Generates stats for a specific network site for a single year
  def self.generate_for_site_year( site, year )
    generate_for_year( year, { site: site } )
  end

  # Generates stats for a specific user for a single year
  def self.generate_for_user_year( user, year, options = {} )
    user = user.is_a?( User ) ? user : User.find_by_id( user )
    return unless user

    year_statistic = YearStatistic.where( year: year ).where( user_id: user ).first_or_create
    users_who_helped_arr, total_users_who_helped, total_ids_received = users_who_helped( year, user )
    users_helped_arr, total_users_helped, total_ids_given = users_helped( year, user )
    json = {
      observations: {
        quality_grade_counts: obervation_counts_by_quality_grade( year, user: user ),
        month_histogram: observations_histogram( year, user: user, interval: "month", d1: "1908-01-01" ),
        week_histogram: observations_histogram( year, user: user, interval: "week" ),
        day_histogram: observations_histogram( year, user: user, interval: "day" ),
        day_last_year_histogram: observations_histogram( year - 1, user: user, interval: "day" ),
        popular: popular_observations( year, user: user ),
        streaks: streaks( year, user: user ),
        outlink_counts: observation_outlink_counts( year, user )
      },
      identifications: {
        category_counts: identification_counts_by_category( year, user: user ),
        month_histogram: identifications_histogram( year, user: user, interval: "month" ),
        week_histogram: identifications_histogram( year, user: user, interval: "week" ),
        day_histogram: identifications_histogram( year, user: user, interval: "day" ),
        users_helped: users_helped_arr,
        total_users_helped: total_users_helped,
        total_ids_given: total_ids_given,
        users_who_helped: users_who_helped_arr,
        total_users_who_helped: total_users_who_helped,
        total_ids_received: total_ids_received,
        iconic_taxon_counts: identification_counts_by_iconic_taxon( year, user, options )
      },
      taxa: {
        leaf_taxa_count: leaf_taxa_count( year, user: user ),
        iconic_taxa_counts: iconic_taxa_counts( year, user: user ),
        tree_taxa: tree_taxa( year, user: user ),
        accumulation: observed_species_accumulation(
          user: user,
          verifiable: true
        ),
        accumulation_by_date_observed: observed_species_accumulation(
          user: user,
          verifiable: true,
          date_field: "observed_on"
        )
        # observed_taxa_changes: observed_taxa_changes( year, user: user )
      },
      growth: {
        observations: observations_histogram_by_created_month( user: user )
      }
    }
    year_statistic.update( data: json )
    # generate the shareable image for this user's locale before returning, so one
    # exists and can be fetched right away. Queue up generating shareables for all
    # locales in a delayed job as that will take longer
    year_statistic.generate_shareable_image( only_user_locale: true )
    year_statistic.delay(
      priority: USER_PRIORITY,
      unique_hash: "YearStatistic::generate_shareable_image::#{user.id}::#{year}"
    ).generate_shareable_image
    year_statistic
  end

  def self.regenerate_existing
    YearStatistic.find_each do | ys |
      if ys.user
        YearStatistic.generate_for_user_year( ys.user, ys.year )
      elsif ys.site
        YearStatistic.generate_for_site_year( ys.site, ys.year )
      else
        YearStatistic.generate_for_year( ys.year )
      end
    end
  end

  def self.regenerate_defaults_for_year( year )
    Site.live.find_each do | site |
      next if Site.default && Site.default.id == site.id

      YearStatistic.generate_for_site_year( site, year )
    end
    # The global YIR will always be the slowest and the most prone to failure so
    # do it last
    generate_for_year( year )
  end

  def self.tree_taxa( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] tree_taxa, year: #{year}, options: #{options}"
    end
    params = { year: year }
    if ( user = options[:user] )
      params[:user_id] = user.id
    end
    if ( site = options[:site] )
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    if user
      if ( place = user.place || user.site.try( :place ) )
        params[:preferred_place_id] = place.id
      end
      if ( locale = user.locale || user.site.try( :locale ) )
        params[:locale] = locale
      end
    elsif site
      if ( place = site.place )
        params[:preferred_place_id] = place.id
      end
      if ( locale = site.locale )
        params[:locale] = locale
      end
    end
    begin
      JSON.parse( INatAPIService.get_json( "/observations/tree_taxa", params, { timeout: 30 } ) )["results"]
    rescue StandardError
      nil
    end
  end

  def self.observations_histogram( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] observations_histogram, year: #{year}, options: #{options}"
    end
    params = {
      d1: "#{year}-01-01",
      d2: "#{year}-12-31",
      interval: "day",
      quality_grade: "research,needs_id"
    }.merge( options )
    if ( user = options[:user] )
      params[:user_id] = user.id
    end
    if ( site = options[:site] )
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    response = INatAPIService.get_json( "/observations/histogram", params, { timeout: 30 } )
    json = JSON.parse( response )
    json["results"][params[:interval]]
  end

  def self.identifications_histogram( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] identifications_histogram, year: #{year}, options: #{options}"
    end
    interval = options[:interval] || "day"
    es_params = YearStatistic.identifications_es_base_params( year ).merge(
      aggregate: {
        histogram: {
          date_histogram: {
            field: "created_at",
            calendar_interval: interval,
            format: "yyyy-MM-dd",
            time_zone: time_zone_for_options( options )
          }
        }
      }
    )
    if options[:user]
      es_params[:filters] << { terms: { "user.id": [options[:user].id] } }
    end
    if ( site = options[:site] )
      es_params[:filters] << if site.place
        { terms: { "observation.place_ids": [site.place.id] } }
      else
        { terms: { "observation.site_id": [site.id] } }
      end
    end
    histogram = {}
    Identification.elastic_search( es_params ).response.aggregations.histogram.buckets.each do | b |
      histogram[b.key_as_string] = b.doc_count
    end
    histogram
  end

  def self.identification_counts_by_category( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] identification_counts_by_category, year: #{year}, options: #{options}"
    end
    es_params = YearStatistic.identifications_es_base_params( year ).merge(
      aggregate: {
        categories: { terms: { field: "category" } }
      }
    )
    if options[:user]
      es_params[:filters] << { terms: { "user.id": [options[:user].id] } }
    end
    if ( site = options[:site] )
      es_params[:filters] << if site.place
        { terms: { "observation.place_ids": [site.place.id] } }
      else
        { terms: { "observation.site_id": [site.id] } }
      end
    end
    Identification.elastic_search( es_params ).response.aggregations.
      categories.buckets.each_with_object( {} ) do | bucket, memo |
      memo[bucket["key"]] = bucket.doc_count
    end
  end

  def self.identification_counts_by_iconic_taxon( year, user, options = {} )
    if options[:debug]
      puts "[#{Time.now}] identification_counts_by_iconic_taxon, year: #{year}, user: #{user}, options: #{options}"
    end
    return unless user

    es_params = identifications_es_base_params( year )
    es_params[:filters] << { terms: { "user.id" => [user.id] } }
    es_params[:aggregate] = {
      iconic_taxa: { terms: { field: "taxon.iconic_taxon_id" } }
    }
    Identification.elastic_search( es_params ).response.aggregations.iconic_taxa.
      buckets.each_with_object( {} ) do | bucket, memo |
      # memo[bucket["key"]] = bucket.doc_count
      # memo
      key = Taxon::ICONIC_TAXA_BY_ID[bucket["key"].to_i].try( :name )
      memo[key] = bucket.doc_count
    end
  end

  def self.obervation_counts_by_quality_grade( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] obervation_counts_by_quality_grade, year: #{year}, options: #{options}"
    end
    params = { year: year }
    params[:user_id] = options[:user].id if options[:user]
    if ( site = options[:site] )
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    elastic_params = Observation.params_to_elastic_query( params )
    Observation.elastic_search( elastic_params.merge(
      size: 0,
      aggregate: {
        quality_grades: { terms: { field: "quality_grade" } }
      }
    ) ).response.aggregations.quality_grades.buckets.each_with_object( {} ) do | bucket, memo |
      memo[bucket["key"]] = bucket.doc_count
    end
  end

  def self.leaf_taxa_count( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] leaf_taxa_count, year: #{year}, options: #{options}"
    end
    params = { year: year, verifiable: true }
    params[:user_id] = options[:user].id if options[:user]
    if ( site = options[:site] )
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    # Observation.elastic_taxon_leaf_counts( Observation.params_to_elastic_query( params ) ).size
    JSON.parse( INatAPIService.get_json( "/observations/species_counts", params,
      { timeout: 30 } ) )["total_results"].to_i
  end

  def self.iconic_taxa_counts( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] iconic_taxa_counts, year: #{year}, options: #{options}"
    end
    params = { year: year, verifiable: true }
    params[:user_id] = options[:user].id if options[:user]
    if ( site = options[:site] )
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    elastic_params = Observation.params_to_elastic_query( params )
    Observation.elastic_search( elastic_params.merge(
      size: 0,
      aggregate: {
        iconic_taxa: { terms: { field: "taxon.iconic_taxon_id" } }
      }
    ) ).response.aggregations.iconic_taxa.buckets.each_with_object( {} ) do | bucket, memo |
      key = Taxon::ICONIC_TAXA_BY_ID[bucket["key"].to_i].try( :name )
      memo[key] = bucket.doc_count
    end
  end

  def self.popular_observations( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] popular_observations, year: #{year}, options: #{options}"
    end
    params = options.merge( year: year, has_photos: true, verifiable: true )
    if ( user = params.delete( :user ) )
      params[:user_id] = user.id
    end
    if ( site = params.delete( :site ) )
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    es_params = Observation.params_to_elastic_query( params )
    # es_params_with_sort = es_params.merge(
    #   sort: {
    #     "_script": {
    #       "type": "number",
    #       "script": {
    #         "lang": "painless",
    #         "inline": "doc['cached_votes_total'].value + doc['comments_count'].value"
    #       },
    #       "order": "desc"
    #     }
    #   }
    # )
    es_params_with_sort = es_params.merge(
      sort: [
        { faves_count: "desc" },
        { comments_count: "desc" }
      ]
    )
    r = Observation.elastic_search( es_params_with_sort ).per_page( 200 ).response
    ids = r.hits.hits.map {| h | h._source.id }
    api_params = {
      id: ids,
      per_page: 200
    }
    if user
      if ( place = user.place || user.site.try( :place ) )
        api_params[:preferred_place_id] = place.id
      end
      if ( locale = user.locale || user.site.try( :locale ) )
        api_params[:locale] = locale
      end
    elsif site
      if ( place = site.place )
        api_params[:preferred_place_id] = place.id
      end
      if ( locale = site.locale )
        api_params[:locale] = locale
      end
    end
    return [] if ids.blank?

    response = INatAPIService.get_json( "/observations", api_params, { timeout: 30 } )
    json = JSON.parse( response )
    json["results"].
      sort_by {| o | [0 - o["faves_count"].to_i, 0 - o["comments_count"].to_i] }.
      each_with_index.map do | o, i |
      json_obs = {
        id: o["id"]
      }
      unless o["photos"].blank?
        json_obs[:photos] = [o["photos"][0].select {| k, _v | %w(url original_dimensions).include?( k ) }]
      end
      if i < 36
        json_obs = json_obs.merge( o.select {| k, _v | %w(comments_count faves_count observed_on).include?( k ) } )
        json_obs[:user] = o["user"].select {| k, _v | %(id login name icon_url).include?( k ) }
        if o["taxon"]
          json_obs[:taxon] = o["taxon"].select {| k, _v | %(id name rank preferred_common_name).include?( k ) }
        end
      end
      json_obs
    end.compact
  end

  def self.users_helped( year, user )
    return unless user

    es_params = YearStatistic.identifications_es_base_params( year )
    es_params[:filters] << { terms: { "user.id" => [user.id] } }
    es_params[:aggregate] = {
      users_helped: { terms: { field: "observation.user_id", size: 40_000 } }
    }
    buckets = Identification.
      elastic_search( es_params ).
      response.
      aggregations.
      users_helped.
      buckets
    users = buckets[0..2].each_with_object( [] ) do | bucket, memo |
      next unless ( helped_user = User.find_by_id( bucket["key"] ) )

      memo << {
        count: bucket.doc_count,
        user: helped_user.as_indexed_json
      }
    end.compact
    [users, buckets.size, buckets.map( &:doc_count ).sum]
  end

  def self.users_who_helped( year, user )
    return unless user

    es_params = YearStatistic.identifications_es_base_params( year )
    es_params[:filters] << { terms: { "observation.user_id" => [user.id] } }
    es_params[:aggregate] = {
      users_helped: { terms: { field: "user.id", size: 40_000 } }
    }
    buckets = Identification.
      elastic_search( es_params ).
      response.
      aggregations.
      users_helped.
      buckets
    users = buckets[0..2].each_with_object( [] ) do | bucket, memo |
      helped_user = User.find_by_id( bucket["key"] )
      next unless helped_user

      memo << {
        count: bucket.doc_count,
        user: helped_user.as_indexed_json
      }
    end.compact
    [users, buckets.size, buckets.map( &:doc_count ).sum]
  end

  def generate_shareable_image( options = {} )
    if options[:debug]
      puts "[#{Time.now}] generate_shareable_image, options: #{options}"
    end
    timeout = 300.seconds
    Timeout.timeout timeout do
      if year >= 2020
        generate_localized_shareable_images( options )
      else
        generate_shareable_image_obs_grid( options )
      end
    end
  rescue Timeout::Error
    Rails.logger.error "Failed to generate shareable image for YearStatistic #{id} in #{timeout}s"
  end

  def generate_localized_shareable_images( options = {} )
    locales_to_generate = if options[:only_user_locale]
      [user&.locale || I18n.locale]
    else
      I18N_SUPPORTED_LOCALES
    end
    locales_to_generate.sort.each do | locale |
      localized_shareable = YearStatisticLocalizedShareableImage.find_or_create_by!(
        year_statistic: self,
        locale: locale
      )
      # even though this instance was passed to the find_or_create_by, the association
      # will not be populated and will still get queried for. Assigning it here saves
      # that query and having to pass the same huge data attribute many times from the DB
      localized_shareable.year_statistic = self
      localized_shareable.generate( options )
    rescue RuntimeError => e
      pp e
    end
  end

  def generate_shareable_image_obs_grid( options = {} )
    if options[:debug]
      puts "[#{Time.now}] generate_shareable_image_obs_grid, options: #{options}"
    end
    return unless ( popular_obs = data&.dig( :observations, :popular ) )
    return if popular_obs.blank?

    work_path = File.join( Dir.tmpdir, "year-stat-#{id}-#{Time.now.to_i}" )
    FileUtils.mkdir_p work_path, mode: 0o755
    image_urls = popular_obs.map {| o | o["photos"].try( :[], 0 ).try( :[], "url" ) }.compact
    return if image_urls.size.zero?

    target_size = 200
    image_urls += image_urls while image_urls.size < target_size
    image_urls = image_urls[0...target_size]

    # Make the montage
    image_urls.each_with_index do | url, i |
      ext = File.extname( URI.parse( url ).path )
      outpath = File.join( work_path, "photo-#{i}#{ext}" )
      run_cmd "curl -f -s -o #{outpath} #{url}"
    end
    inpaths = File.join( work_path, "photo-*" )
    montage_path = File.join( work_path, "montage.jpg" )
    run_cmd "montage #{inpaths} -tile 20x -geometry 50x50+0+0 #{montage_path}"

    # Get the icon
    icon_url = if user
      ApplicationController.helpers.image_url( user.icon.url( :large ) ).to_s.gsub( %r{([^:])//}, "\\1/" )
    elsif site
      ApplicationController.helpers.image_url( site.logo_square.url ).to_s.gsub( %r{([^:])//}, "\\1/" )
    elsif Site.default
      ApplicationController.helpers.image_url( Site.default.logo_square.url ).to_s.gsub( %r{([^:])//}, "\\1/" )
    else
      ApplicationController.helpers.image_url( "bird.png" ).to_s.gsub( %r{([^:])//}, "\\1/" )
    end
    icon_ext = File.extname( URI.parse( icon_url ).path )
    icon_path = File.join( work_path, "icon#{icon_ext}" )
    run_cmd "curl -f -s -o #{icon_path} #{icon_url}"

    # Resize icon to a 500x500 square
    square_icon_path = File.join( work_path, "square_icon.jpg" )
    run_cmd <<~BASH
      convert #{icon_path} -resize "500x500^" \
                        -gravity Center  \
                        -extent 500x500  \
              #{square_icon_path}
    BASH

    # Apply circle mask and white border
    circle_path = File.join( work_path, "circle.png" )
    run_cmd <<~BASH
      convert -size 500x500 xc:black -fill white \
        -draw "translate 250,250 circle 0,0 0,250" -alpha off #{circle_path}
    BASH
    circle_icon_path = File.join( work_path, "circle-user-icon.png" )
    run_cmd <<~BASH
      convert #{square_icon_path} #{circle_path} \
        -alpha Off -compose CopyOpacity -composite \
        -stroke white -strokewidth 20 -fill transparent -draw "translate 250,250 circle 0,0 0,240" \
        -scale 50% \
        #{circle_icon_path}
    BASH

    # Apply mask to the montage
    ellipse_mask_path = File.join( work_path, "ellipse_mask.png" )
    run_cmd "convert -size 1000x500 radial-gradient:\"#ccc\"-\"#111\" #{ellipse_mask_path}"
    ellipse_montage_path = File.join( work_path, "ellipse_montage.jpg" )
    run_cmd <<~BASH
      convert #{montage_path} #{ellipse_mask_path} \
        -alpha Off -compose multiply -composite\
        #{ellipse_montage_path}
    BASH

    # Overlay the icon onto the montage
    montage_with_icon_path = File.join( work_path, "montage_with_icon.jpg" )
    run_cmd "composite -gravity center #{circle_icon_path} #{ellipse_montage_path} #{montage_with_icon_path}"

    # Add the text
    light_font_path = File.join( Rails.root, "public", "fonts", "Whitney-Light-Pro.otf" )
    medium_font_path = File.join( Rails.root, "public", "fonts", "Whitney-Medium-Pro.otf" )
    final_path = File.join( work_path, "final.jpg" )
    owner = if user
      user.name.blank? ? user.login : user.name
    else
      ""
    end
    title = if user
      user_site = user.site || Site.default
      locale = user.locale || user_site.locale || I18n.locale
      site_name = user_site.site_name_short.blank? ? user_site.name : user_site.site_name_short
      I18n.t( :year_on_site, year: year, site: site_name, locale: locale )
    elsif site
      locale = site.locale || I18n.locale
      site_name = site.site_name_short.blank? ? site.name : site.site_name_short
      I18n.t( :year_on_site, year: year, locale: locale, site: site_name )
    else
      default_site = Site.default
      locale = default_site.locale || I18n.locale
      site_name = default_site.site_name_short.blank? ? default_site.name : default_site.site_name_short
      I18n.t( :year_on_site, year: year, locale: locale, site: site_name )
    end
    title = title.mb_chars.upcase
    obs_count = begin
      quality_grade_counts = data.dig( "observations", "quality_grade_counts" )
      quality_grade_counts["research"].to_i + quality_grade_counts["needs_id"].to_i
    rescue StandardError
      nil
    end
    medium_font_path = "Lato-Regular" if owner.non_latin_chars?
    light_font_path = "Lato-Light" if title.non_latin_chars?
    if obs_count.to_i.positive?
      locale = user.locale if user
      locale ||= site.locale if site
      locale ||= I18n.locale
      obs_text = I18n.t(
        "x_observations",
        count: ApplicationController.helpers.number_with_delimiter( obs_count, locale: locale ),
        locale: locale
      ).mb_chars.upcase
      medium_font_path = "Lato-Regular" if obs_text.non_latin_chars?
      run_cmd <<~BASH
        convert #{montage_with_icon_path} \
          -fill white -font #{medium_font_path} -pointsize 24 -gravity north -annotate 0x0+0+30 "#{owner}" \
          -fill white -font #{light_font_path} -pointsize 65 -gravity north -annotate 0x0+0+60 "#{title}" \
          -fill white -font #{medium_font_path} -pointsize 46 -gravity south -annotate 0x0+0+50 "#{obs_text}" \
          #{final_path}
      BASH
    else
      run_cmd <<~BASH
        convert #{montage_with_icon_path} \
          -fill white -font #{medium_font_path} -pointsize 24 -gravity north -annotate 0x0+0+30 "#{owner}" \
          -fill white -font #{light_font_path} -pointsize 65 -gravity north -annotate 0x0+0+60 "#{title}" \
          #{final_path}
      BASH
    end

    self.shareable_image = File.open( final_path )
    save!
  end

  def shareable_image_for_locale( locale )
    if year_statistic_localized_shareable_images.any?
      year_statistic_localized_shareable_images.detect do | si |
        si.locale == locale.to_s
      end&.shareable_image
    else
      shareable_image
    end
  end

  def self.end_of_month( date )
    n = date + 1.month
    Date.parse( "#{n.year}-#{n.month}-01" ) - 1.day
  end

  def self.observed_species_accumulation( params = {}, options = {} )
    debug = params.delete( :debug ) || options[:debug]
    if debug
      puts "[#{Time.now}] observed_species_accumulation, params: #{params}, options: #{options}"
    end
    interval = params.delete( :interval ) || "month"
    date_field = params.delete( :date_field ) || "created_at"
    params[:user_id] = params[:user].id if params[:user]
    params[:quality_grade] = params[:quality_grade] || "research,needs_id"
    if ( site = params[:site] )
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    params[:hrank] = Taxon::SPECIES
    elastic_params = Observation.params_to_elastic_query( params )
    histogram_params = elastic_params.merge(
      size: 0,
      track_total_hits: true,
      aggs: {
        histogram: {
          date_histogram: {
            field: date_field,
            calendar_interval: interval,
            format: "yyyy-MM-dd",
            time_zone: YearStatistic.time_zone_for_options( params )
          },
          aggs: {
            taxon_ids: {
              terms: { field: "taxon.min_species_ancestry", size: 100_000 }
            }
          }
        }
      }
    )
    bucketer = proc do | es_params |
      buckets = Observation.elastic_search( es_params ).response.aggregations.histogram.buckets
      if debug
        d1_filter = es_params[:filters].detect do | f |
          f[:range] && f[:range][date_field] && f[:range][date_field][:gte]
        end
        d2_filter = es_params[:filters].detect do | f |
          f[:range] && f[:range][date_field] && f[:range][date_field][:lte]
        end
        if d1_filter && d2_filter
          d1 = Date.parse( d1_filter[:range][date_field][:gte] )
          d2 = Date.parse( d2_filter[:range][date_field][:lte] )
        else
          d1 = Date.parse( "2008-01-01" )
          d2 = Date.today
        end
        bucket_dates = buckets.map {| bucket | bucket["key_as_string"] }.sort
        species_ids = buckets.map do | bucket |
          bucket.taxon_ids.buckets.map do | b |
            b["key"].split( "," ).map( &:to_i )
          end
        end.flatten.uniq
        Rails.logger.info <<~MSG
          observed_species_accumulation results for #{d1} - #{d2}:
          #{buckets.size} buckets, #{bucket_dates.first} - #{bucket_dates.last},
          #{species_ids.size} species
        MSG
      end
      buckets
    end

    histogram_buckets = call_and_rescue_with_partitioner(
      bucketer,
      [histogram_params],
      [
        Elasticsearch::Transport::Transport::Errors::BadRequest,
        Elasticsearch::Transport::Transport::Errors::ServiceUnavailable,
        Elasticsearch::Transport::Transport::Errors::TooManyRequests,
        Faraday::TimeoutError
      ],
      exception_checker: proc {| e | e.message =~ /(timed out|too_many_buckets_exception|Data too large)/ },
      parallel: YearStatistic::NUM_ES_WORKERS,
      debug: debug
    ) do | args |
      es_params = args[0].dup
      d1_filter = es_params[:filters].detect {| f | f[:range] && f[:range][date_field] && f[:range][date_field][:gte] }
      d2_filter = es_params[:filters].detect {| f | f[:range] && f[:range][date_field] && f[:range][date_field][:lte] }
      es_params[:filters] = es_params[:filters].delete_if {| f | f[:range] && f[:range][date_field] }
      if d1_filter && d2_filter
        d1 = Date.parse( d1_filter[:range][date_field][:gte] )
        d2 = Date.parse( d2_filter[:range][date_field][:lte] )
      else
        d1 = Date.parse( "2008-01-01" )
        d2 = YearStatistic.end_of_month( Date.today )
      end
      half = ( d2 - d1 ) / 2
      d1_p1 = d1
      d2_p1 = YearStatistic.end_of_month( d1 + half.days )
      d1_p2 = d2_p1 + 1.day
      d2_p2 = d2
      es_params1 = es_params.dup
      es_params1[:filters] += [
        { range: { date_field => { gte: d1_p1.to_s } } },
        { range: { date_field => { lte: d2_p1.to_s } } }
      ]
      es_params2 = es_params.dup
      es_params2[:filters] += [
        { range: { date_field => { gte: d1_p2.to_s } } },
        { range: { date_field => { lte: d2_p2.to_s } } }
      ]
      new_params = [es_params1, es_params2]
      if debug
        puts
        puts "observed_species_accumulation partitions: #{d1_p1} - #{d2_p1}, #{d1_p2} - #{d2_p2}"
        puts
      end
      new_params
    end

    accumulation_with_all_species_ids = histogram_buckets.each_with_index.each_with_object( [] ) do | pair, memo |
      bucket, i = pair
      interval_species_ids = bucket.taxon_ids.buckets.map {| b | b["key"].split( "," ).map( &:to_i ) }.flatten.uniq
      interval_species_ids = Taxon.where( id: interval_species_ids, rank: Taxon::SPECIES ).pluck( :id )
      accumulated_species_ids = if i.positive? && memo[i - 1]
        memo[i - 1][:accumulated_species_ids]
      else
        []
      end
      novel_species_ids = interval_species_ids - accumulated_species_ids
      memo << {
        date: bucket["key_as_string"],
        accumulated_species_ids: accumulated_species_ids + novel_species_ids,
        novel_species_ids: novel_species_ids,
        species_ids: interval_species_ids
      }
    end
    accumulation_with_all_species_ids.map do | acc_interval |
      {
        date: acc_interval[:date],
        accumulated_species_count: acc_interval[:accumulated_species_ids].size,
        novel_species_ids: acc_interval[:novel_species_ids],
        species_count: acc_interval[:species_ids].size
      }
    end
  end

  def self.publications( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] publications, year: #{year}, options: #{options}"
    end

    gbif_endpoint = "https://api.gbif.org/v1/literature/search"
    gbif_params = {
      # iNat RG Observations dataset identifier on GBIF We don't publish site-
      # specific datasets, so there's no reason not to hard-code it here.
      gbifDatasetKey: "50c9509d-22c7-4a22-a47d-8c48425ef4a7",
      literatureType: "journal",
      year: year,
      limit: 50
    }
    gbif_url = "#{gbif_endpoint}?#{gbif_params.to_query}"
    response = JSON.parse( RestClient.get( gbif_url ) )

    new_results = []
    response["results"].each do | result |
      altmetric_score = nil

      if ( doi = result.dig( "identifiers", "doi" ) )
        url = "https://api.altmetric.com/v1/doi/#{doi}"
        begin
          am_response = RestClient.get( url )
          altmetric_score = JSON.parse( am_response )["score"]
        rescue RestClient::NotFound => e
          Rails.logger.debug "[DEBUG] Request failed for #{url}: #{e}"
        end
        sleep( 1 )
      end

      new_result = result.slice(
        "title",
        "authors",
        "year",
        "source",
        "websites",
        "publisher",
        "id",
        "identifiers"
      )

      new_result["altmetric_score"] = altmetric_score

      gbif_dois = result["tags"].select do | tag |
        tag.start_with?( "gbifDOI:" )
      end
      gbif_dois = gbif_dois.take( 10 )
      new_result["_gbifDOIs"] = gbif_dois.map {| tag | tag.delete_prefix( "gbifDOI:" ) }

      if new_result["authors"].size == 1 && new_result["authors"][0]["lastName"] =~ /doesn't match/
        new_result["authors"] = []
      end

      new_results << new_result
    end

    {
      results: new_results.sort_by {| result | result["altmetric_score"].to_f * -1 }[0..5],
      url: gbif_url,
      count: response["count"]
    }
  end

  def self.observations_histogram_by_created_month( options = {} )
    if options[:debug]
      puts "[#{Time.now}] observations_histogram_by_created_month, options: #{options}"
    end
    filters = [
      { terms: { quality_grade: ["research", "needs_id"] } }
    ]
    if ( site = options[:site] )
      filters << if site.place
        { terms: { place_ids: [site.place.id] } }
      else
        { terms: { site_id: [site.id] } }
      end
    end
    if ( user = options[:user] )
      filters << { term: { "user.id" => user.id } }
    end
    es_params = {
      size: 0,
      filters: filters,
      aggregate: {
        histogram: {
          date_histogram: {
            field: "created_at_details.date",
            calendar_interval: "month",
            format: "yyyy-MM-dd",
            time_zone: time_zone_for_options( options )
          }
        }
      }
    }
    histogram = {}
    Observation.elastic_search( es_params ).response.aggregations.histogram.buckets.each do | b |
      histogram[b.key_as_string] = b.doc_count
    end
    histogram
  end

  def self.users_histogram_by_created_month( options = {} )
    if options[:debug]
      puts "[#{Time.now}] users_histogram_by_created_month, options: #{options}"
    end
    scope = User.group( "EXTRACT('year' FROM created_at) || '-' || EXTRACT('month' FROM created_at)" ).
      where( "suspended_at IS NULL AND created_at > '2008-03-01' AND observations_count > 0" )
    if ( site = options[:site] )
      scope = scope.where( "site_id = ?", site )
    end
    scope.count.map do | k, v |
      ["#{k.split( '-' ).map {| s | s.rjust( 2, '0' ) }.join( '-' )}-01", v]
    end.sort.to_h
  end

  def self.observation_counts_by_country( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] observation_counts_by_country, year: #{year}, options: #{options}"
    end
    Place.where( admin_level: 0 ).all.each_with_object( [] ) do | p, memo |
      r = INatAPIService.observations( per_page: 0, verifiable: true,
        created_d1: "#{year}-01-01",
        created_d2: "#{year}-12-31",
        place_id: p.id )
      year_count = r ? r.total_results : 0
      next if year_count.to_i <= 0

      r = INatAPIService.observations( per_page: 0, verifiable: true,
        created_d1: "#{year - 1}-01-01",
        created_d2: "#{year - 1}-12-31",
        place_id: p.id )
      last_year_count = r ? r.total_results : 0
      memo << {
        place_id: p.id,
        place_code: p.code,
        place_bounding_box: p.bounding_box,
        name: p.name,
        observations: year_count,
        observations_last_year: last_year_count
      }
    end
  end

  def self.streaks( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] streaks, year: #{year}, options: #{options}"
    end
    options = options.clone
    debug = options[:debug]
    streak_length = 5
    base_query = { quality_grade: "research,needs_id", d2: "#{year}-12-31" }
    if options[:site]
      base_query = base_query.merge( site_id: options[:site].id )
    end
    if options[:user]
      base_query = base_query.merge( user_id: options[:user].id )
    end

    streaks = []
    current_streaks = {}
    previous_user_ids = []

    streak_bucketer = proc do | query |
      elastic_params = Observation.params_to_elastic_query( query )
      Observation.elastic_search( elastic_params.merge(
        size: 0,
        aggs: {
          histogram: {
            date_histogram: {
              field: "observed_on",
              calendar_interval: "day",
              format: "yyyy-MM-dd",
              time_zone: time_zone_for_options( options )
            },
            aggs: {
              user_ids: {
                terms: {
                  field: "user.id",
                  size: 300_000
                }
              }
            }
          }
        }
      ) ).response.aggregations.histogram.buckets
    end
    puts "[#{Time.now}] Aggregating all relevant observations by day and user..." if debug
    histogram_buckets = call_and_rescue_with_partitioner(
      streak_bucketer,
      base_query,
      [
        Elasticsearch::Transport::Transport::Errors::ServiceUnavailable,
        Faraday::TimeoutError
      ],
      exception_checker: proc {| e | e.message =~ /(timed out|too_many_buckets_exception)/ },
      parallel: NUM_ES_WORKERS,
      debug: debug
    ) do | args |
      query = args[0]
      # Assume no one has been on a streak since before 2008-01-01
      puts "[#{Time.now}] partitioning #{query}" if debug
      d1 = ( query[:d1] && Date.parse( query[:d1] ) ) || Date.parse( "2008-01-01" )
      d2 = ( query[:d2] && Date.parse( query[:d2] ) ) || Date.today

      # Even n-ary partitioner (splits into n even partitions)
      # num_breaks = 8
      # break_interval = ( d2 - d1 ) / num_breaks
      # new_queries = []
      # num_breaks.times do | i |
      #   interval_d1 = d1 + ( i * break_interval ).days
      #   interval_d2 = interval_d1 + break_interval.days - 1.day
      #   interval_query = query.dup
      #   new_queries << interval_query.merge( d1: interval_d1.to_s, d2: interval_d2.to_s )
      # end

      # If we're partitioning more than a year, assume a lot more buckets in
      # more recent partitions
      if d2 - d1 > 365
        # Weighted binary partitioner
        weight = 0.9
        break_point = ( ( d2 - d1 ) * weight ).ceil
        new_queries = [
          query.merge( d1: d1.to_s, d2: ( d1 + break_point.days ).to_s ),
          query.merge( d1: ( d1 + ( break_point + 1 ).days ).to_s, d2: d2.to_s )
        ]
      # If we're partitioning less than a year, assume variance has more to do
      # with seasonality and events like CNC, so take a simple even approach
      else
        # Even binary partitioner
        half = ( d2 - d1 ) / 2
        new_queries = [
          query.merge( d1: d1.to_s, d2: ( d1 + half.days ).to_s ),
          query.merge( d1: ( d1 + ( half + 1 ).days ).to_s, d2: d2.to_s )
        ]
      end

      # # Logarithmic n-ary partitioner
      # num_breaks = 4
      # # break_interval = ( d2 - d1 ) / num_breaks
      # new_queries = []
      # num_breaks.times do | i |
      #   d2_offset = i**Math.log( d2 - d1, num_breaks )
      #   d1_offset = ( i + 1 )**Math.log( d2 - d1, num_breaks )
      #   interval_d1 = d2 - d1_offset.days
      #   interval_d1 += 1.day unless i == 0
      #   interval_d2 = d2 - d2_offset.days
      #   interval_query = query.dup
      #   new_queries << interval_query.merge( d1: interval_d1.to_s, d2: interval_d2.to_s )
      # end

      puts "[#{Time.now}] partitioned into #{new_queries}" if debug
      new_queries
    end
    puts "[#{Time.now}] Processing #{histogram_buckets.size} buckets..." if debug
    histogram_buckets.each_with_index do | bucket, bucket_i |
      date = bucket["key_as_string"]
      puts "[#{Time.now}] Processing #{date}" if debug
      user_ids = bucket.user_ids.buckets.map {| b | b["key"].to_i }
      user_ids.each do | streaking_user_id |
        current_streaks[streaking_user_id] ||= 0
        current_streaks[streaking_user_id] += 1
      end

      # Finished users are all the users who were present in the previous day
      # but not in this one. For each of these, we need to add their streaks
      # with the stop date set to the previous day
      stop_date = ( Date.parse( date ) - 1.day )
      finished_user_ids = previous_user_ids - user_ids
      puts "[#{Time.now}] \t#{date}: #{user_ids.size} users, #{finished_user_ids.size} finished" if debug
      finished_user_ids.each do | user_id |
        if debug && options[:user]
          puts "[#{Time.now}] \tFinished streak of length #{current_streaks[user_id]}"
        end
        if current_streaks[user_id] && current_streaks[user_id] >= streak_length
          if debug && options[:user]
            puts "[#{Time.now}] \tAdding streak #{stop_date + 1.day - ( current_streaks[user_id] ).days} - #{stop_date}"
          end
          streaks << {
            user_id: user_id,
            days: current_streaks[user_id],
            stop: stop_date.to_s,
            start: ( stop_date + 1.day - ( current_streaks[user_id] ).days ).to_s
          }
        end
        current_streaks[user_id] = nil
      end

      # If this is the final day and there are still streaks in progress, we
      # need to add their streaks with the stop today set to *this* day
      if bucket_i == ( histogram_buckets.size - 1 ) # && range_i == ( ranges.size - 1 )
        streaking_user_ids = current_streaks.keys
        stop_date = Date.parse( date )
        puts "[#{Time.now}] Processing final day for #{streaking_user_ids.size} streaking users..." if debug
        streaking_user_ids.each do | user_id |
          if current_streaks[user_id] && current_streaks[user_id] >= streak_length
            streaks << {
              user_id: user_id,
              days: current_streaks[user_id],
              stop: stop_date.to_s,
              start: ( stop_date + 1.day - ( current_streaks[user_id] ).days ).to_s
            }
          end
          current_streaks[user_id] = nil
        end
      end

      previous_user_ids = user_ids
    end
    return nil if streaks.blank?

    max_stop_date = Date.parse( streaks.map {| s | s[:stop] }.max ) - 2.days
    year_start = Date.parse( "#{year}-01-01" )
    year_stop = Date.parse( "#{year}-12-31" )
    year_range = ( year_start..year_stop )
    top_streaks = streaks.select do | s |
      streak_in_progress = Date.parse( s[:stop] ) >= max_stop_date
      start_date = Date.parse( s[:start] )
      stop_date = Date.parse( s[:stop] )
      streak_started_this_year  = year_range.include?( start_date )
      streak_stopped_this_year  = year_range.include?( stop_date )
      # Only counting streaks in progress and streaks started this year EXCEPT
      # when looking at an individual user's streaks
      if options[:user]
        streak_in_progress || streak_stopped_this_year
      else
        streak_in_progress || streak_started_this_year
      end
    end
    top_streaks = top_streaks.sort_by {| s | s[:days] * -1 }[0..100]
    top_streaks_user_ids = top_streaks.map {| u | u[:user_id] }.uniq
    puts "[#{Time.now}] Fetching top streak users..." if debug
    top_streaks_users = User.where( id: top_streaks_user_ids )
    puts "[#{Time.now}] Generating logins and icons for top streak users..." if debug
    top_streaks.map do | s |
      u = top_streaks_users.detect {| streak_user | streak_user.id == s[:user_id] }
      if u.suspended?
        nil
      else
        s.merge(
          login: u.login,
          icon_url: ApplicationController.helpers.image_url( u.icon.url( :medium ) ).to_s.gsub( %r{([^:])//}, "\\1/" )
        )
      end
    end.compact
  end

  def self.translators( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] translators, year: #{year}, options: #{options}"
    end
    return unless CONFIG.crowdin&.projects

    locale_to_ci_code = {
      "es" => "es-ES",
      "pt" => "pt-PT"
    }
    data = { languages: {}, users: {} }
    staff_usernames = User.admins.pluck( :login ) + %w(alexinat inaturalist)
    CONFIG.crowdin.projects.to_h.each_key do | project_name |
      project = CONFIG.crowdin.projects.send( project_name )
      info_r = RestClient.get(
        "https://api.crowdin.com/api/project/#{project.identifier}/info?key=#{project.key}&json"
      )
      info_j = JSON.parse( info_r )
      translated_locales = I18n.t( "locales" ).keys.map( &:to_s )
      info_j["languages"].each do | lang |
        next if data[:languages][lang[:name]]

        data[:languages][lang["name"]] = {}
        data[:languages][lang["name"]]["name"] = lang["name"]
        data[:languages][lang["name"]]["code"] = lang["code"]
        if translated_locales.include?( lang["code"] )
          data[:languages][lang["name"]][:locale] = lang["code"]
          locale_to_ci_code[lang["code"].to_s] ||= lang["code"]
        elsif ( two_letter = lang["code"].split( "-" )[0] ) && translated_locales.include?( two_letter )
          data[:languages][lang["name"]][:locale] = two_letter
          locale_to_ci_code[two_letter.to_s] ||= lang["code"]
        end
      end
      export_params = {
        key: project.key,
        json: true,
        format: "csv",
        date_from: "#{year - 1}-01-01+00:00",
        date_to: "#{year}-12-31+23:00"
      }
      if options[:site]&.locale
        export_params[:language] = locale_to_ci_code[options[:site].locale]
      end
      export_r = RestClient.post(
        "https://api.crowdin.com/api/project/#{project.identifier}/reports/top-members/export",
        export_params
      )
      export_j = JSON.parse( export_r )
      next unless export_j["success"]

      report_r = RestClient.get(
        "https://api.crowdin.com/api/project/#{project.identifier}/reports/top-members/download?key=#{project.key}&hash=#{export_j['hash']}"
      )
      CSV.parse( report_r, headers: true ).each do | row |
        next unless row["Languages"]
        next if staff_usernames.include?( row["Name"] )

        username = row["Name"][/\((.+)\)/, 1]
        next if staff_usernames.include?( username )

        languages = row["Languages"].split( ";" ).map( &:strip ).grep_v( /English/ )
        next if languages.blank?

        username ||= row["Name"]
        data[:users][username] ||= {}
        data[:users][username][:name] ||= row["Name"].gsub( /\(.+\)/, "" ).strip
        data[:users][username]["words_#{project_name}"] = row["Translated (Words)"].to_i
        data[:users][username]["approved_#{project_name}"] = row["Approved (Words)"].to_i
        data[:users][username][:languages] = languages
      end
    end
    data
  end

  def self.observed_taxa_counts( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] observed_taxa_counts, year: #{year}, options: #{options}"
    end
    params = options.merge( year: year, verifiable: true, page: 1 )
    params[:user_id] = options[:user].id if options[:user]
    data = {}
    loop do
      puts "Fetching results for #{params}"
      results = INatAPIService.observations_species_counts( params ).results
      break if results.size.zero?

      results.each do | r |
        r["taxon"]["ancestor_ids"].each do | tid |
          data[tid] ||= {}
          data[tid][:observations] = data[tid][:observations].to_i + r["count"]
          data[tid][:species] = if r["taxon"]["id"] == tid
            1
          else
            data[tid][:species].to_i + 1
          end
        end
      end
      params[:page] += 1
    end
    data
  end

  def self.observed_taxa_changes( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] observed_taxa_changes, year: #{year}, options: #{options}"
    end
    # final number of top gains and losses to return
    final_cutoff = 30
    this_years_taxa = observed_taxa_counts( year, options )
    last_years_taxa = observed_taxa_counts( year - 1, options )
    all_taxon_ids = ( this_years_taxa.keys + last_years_taxa.keys ).uniq
    # top most observose taxa to derive leaves from. since coarser rank taxa
    # will always have higher counts, the lower this number is the more coarser
    # taxa will be favored
    leaf_cuttoff = [( 0.02 * all_taxon_ids.size ).ceil, final_cutoff].max
    data = {}
    [:species, :observations].each do | metric |
      deltas = all_taxon_ids.each_with_object( {} ) do | taxon_id, memo |
        memo[taxon_id] =
          this_years_taxa[taxon_id].try( :[], metric ).to_i - last_years_taxa[taxon_id].try( :[], metric ).to_i
      end
      top_losses = deltas.select {| _k, v | v.negative? }.sort_by {| _k, v | -1 * v.abs }[0..leaf_cuttoff]
      top_gains = deltas.select {| _k, v | v.positive? }.sort_by {| _k, v | -1 * v.abs }[0..leaf_cuttoff]
      top_taxon_ids = ( top_losses.map( &:first ) + top_gains.map( &:first ) ).uniq
      taxa = Taxon.where( id: top_taxon_ids ).index_by( &:id )
      losses_ancestor_ids = taxa.fetch_values( *top_losses.map( &:first ) ).collect( &:ancestor_ids ).flatten.uniq
      top_losses = top_losses.reject {| taxon_id, _delta | losses_ancestor_ids.include?( taxon_id ) }[0..final_cutoff]
      gains_ancestor_ids = taxa.fetch_values( *top_gains.map( &:first ) ).collect( &:ancestor_ids ).flatten.uniq
      top_gains = top_gains.reject {| taxon_id, _delta | gains_ancestor_ids.include?( taxon_id ) }[0..final_cutoff]
      final_taxon_ids = ( top_losses.map( &:first ) + top_gains.map( &:first ) ).uniq
      data[metric] = final_taxon_ids.collect do | taxon_id |
        taxon = taxa[taxon_id]
        {
          taxon: taxon.as_indexed_json( no_details: true ).keep_if do | k, _v |
            [:id, :name, :rank, :rank_level, :default_photo, :is_active].include?( k )
          end.merge(
            iconic_taxon_name: taxon.iconic_taxon_name,
            preferred_common_name: taxon.common_name( user: options[:user] ).try( :name )
          ),
          delta: deltas[taxon_id]
        }
      end
    end
    data
  end

  def self.donors( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] donors, year: #{year}, options: #{options}"
    end
    options = options.clone
    debug = options.delete( :debug )
    limit = options.delete( :limit )
    donorbox_email = CONFIG.donorbox.email
    donorbox_key = CONFIG.donorbox.key
    return if donorbox_key.blank?

    page = 1
    per_page = 100
    donations = []
    donation_encountered = {}
    loop do
      break if limit && donations.size >= limit

      url = "https://donorbox.org/api/v1/donations?page=#{page}&per_page=#{per_page}"
      puts "Fetching #{url}" if debug
      response = RestClient.get( url, {
        "Authorization" => "Basic #{Base64.strict_encode64( "#{donorbox_email}:#{donorbox_key}" ).strip}",
        "User-Agent" => "iNaturalist/Donorbox"
      } )
      json = JSON.parse( response )
      puts "Received #{json.size} donations" if debug
      break if json.size.zero?

      page_donations = json.select {| d | DateTime.parse( d["donation_date"] ).year == year }
      puts "Received #{page_donations.size} donations for #{year}" if debug
      if page_donations.size.zero?
        page += 1
        next
      end
      page_donations.each do | d |
        next if d["amount_refunded"].to_f.positive?
        next unless d["status"] == "paid"
        next if donation_encountered[d["id"]]

        donation_encountered[d["id"]] = true
        net_amount_usd = d["converted_net_amount"] || d["converted_amount"] || d["amount"]
        next unless net_amount_usd

        donations << {
          # net_amount_usd: net_amount_usd.to_f,
          date: Date.parse( d["donation_date"] ),
          donor_id: d["donor"]["id"],
          recurring: d["recurring"]
          # monthly: d["campaign"] && d["campaign"]["name"].to_s =~ /Monthly Support/
        }
      end
      puts "#{donations.size} total donations for #{year} so far" if debug
      page += 1
    end
    puts "Received #{donations.size} total donations" if debug
    monthly = donations.each_with_object( {} ) do | d, memo |
      key = d[:date].strftime( "%Y-%m-01" )
      memo[key] ||= {}
      # memo[key][:total_net_amount_usd] = memo[key][:total_net_amount_usd].to_f + d[:net_amount_usd]
      memo[key][:total_donors] ||= Set.new
      memo[key][:total_donors] << d[:donor_id]
      next unless d[:recurring]

      # memo[key][:recurring_net_amount_usd] = memo[key][:recurring_net_amount_usd].to_f + d[:net_amount_usd]
      memo[key][:recurring_donors] ||= Set.new
      memo[key][:recurring_donors] << d[:donor_id]
      # if d[:monthly]
      #   memo[key][:monthly_net_amount_usd] = memo[key][:monthly_net_amount_usd].to_f + d[:net_amount_usd]
      #   memo[key][:monthly_donors] ||= Set.new
      #   memo[key][:monthly_donors] << d[:donor_id]
      # end
    end
    monthly.keys.sort.map do | key |
      d = monthly[key]
      {
        date: key,
        # total_net_amount_usd: d[:total_net_amount_usd],
        total_donors: d[:total_donors].size,
        # recurring_net_amount_usd: d[:recurring_net_amount_usd],
        recurring_donors: d[:recurring_donors].size
        # monthly_net_amount_usd: d[:monthly_net_amount_usd],
        # monthly_donors: d[:monthly_donors].size
      }
    end
  end

  def self.monthly_supporters( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] monthly_supporters, year: #{year}, options: #{options}"
    end
    users = User.limit( 30 ).
      where( "donorbox_plan_type = 'monthly'" ).
      where( "donorbox_plan_status = 'active'" ).
      where( "donorbox_plan_started_at IS NOT NULL" ).
      joins( :stored_preferences ).
      where( "preferences.name = 'monthly_supporter_badge' AND preferences.value = 't'" ).
      order( Arel.sql( "RANDOM()" ) )
    users.reject( &:suspended? ).map do | user |
      {
        login: user.login,
        name: user.name,
        icon_url: FakeView.image_url( user.icon.url( :medium ) ).to_s.gsub( %r{([^:])//}, "\\1/" )
      }
    end
  end

  def self.identifications_es_base_params( year )
    {
      size: 0,
      filters: [
        { range: { created_at: { gte: "#{year}-01-01" } } },
        { range: { created_at: { lte: "#{year}-12-31" } } },
        { terms: { own_observation: [false] } },
        { terms: { "observation.quality_grade": ["research", "needs_id"] } },
        { terms: { current: [true] } }
      ],
      inverse_filters: [
        { exists: { field: "taxon_change_id" } }
      ]
    }
  end

  def self.time_zone_for_options( options = {} )
    return "UTC" unless options[:user]
    return "UTC" if options[:user].time_zone.blank?
    return "UTC" unless ( tz = ActiveSupport::TimeZone[options[:user].time_zone] )

    tz.tzinfo.name
  end

  def self.github_pull_requests( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] github_pull_requests, year: #{year}, options: #{options}"
    end
    year_pulls = []
    repos = %w(
      inaturalist
      iNaturalistAndroid
      iNaturalistAPI
      INaturalistIOS
      inaturalistjs
      iNaturalistReactNative
      SeekReactNative
    )
    repos.each do | repo |
      page = 1
      loop do
        url = "https://api.github.com/repos/inaturalist/#{repo}/pulls?state=closed&page=#{page}&per_page=100&direction=desc"
        puts "Getting #{url}" if options[:debug]
        pulls = try_and_try_again( [RestClient::Forbidden, RestClient::TooManyRequests] ) do
          JSON.parse( RestClient.get( url ) )
        end
        relevant_pulls = ( pulls || [] ).select do | pull |
          pull["merged_at"] &&
            !%w(MEMBER COLLABORATOR).include?( pull["author_association"] ) &&
            # For some reason the MEMBER and COLLABOTOR filters don't always
            # filter out everyone on staff...
            !%w(
              albullington
              budowski
              carrieseltzer
              dependabot[bot]
              jtklein
              meru20
              sylvain-morin
            ).include?( pull["user"]["login"] ) &&
            ( merge_date = Date.parse( pull["merged_at"] ) ) &&
            merge_date.year == year
        end
        break if relevant_pulls.blank? && !year_pulls.blank?

        year_pulls += relevant_pulls
        page += 1
      end
    end
    year_pulls.map do | pull |
      new_pull = pull.slice( "title", "merged_at", "html_url" )
      new_pull["user"] = pull["user"].slice( "login", "avatar_url", "html_url" )
      new_pull
    end
  end

  # returns a hash indexed by user_id, containing a hash of activity counts.
  # :observations contains a count of observations created in the given year
  # :identifications contains a count of identifications created in the
  # given year on observations other than their own
  def self.user_activity_counts( year, options = {} )
    if options[:debug]
      puts "[#{Time.now}] user_activity_counts, year: #{year}, options: #{options}"
    end
    max_user_id = User.maximum( :id ) || 0
    start_id = 1
    batch_size = 500_000
    activity_counts_by_user = {}
    while start_id <= max_user_id
      es_params = {
        size: 0,
        filters: [{
          range: {
            "user.id": {
              gte: start_id,
              lt: start_id + batch_size
            }
          }
        }, {
          term: {
            "created_at_details.year": year
          }
        }],
        aggregate: {
          users: {
            terms: {
              field: "user.id",
              size: batch_size
            }
          }
        }
      }
      observation_es_params = es_params.deep_dup
      identifications_es_params = es_params.deep_dup
      identifications_es_params[:filters] << {
        term: {
          own_observation: false
        }
      }
      if ( site = options[:site] )
        if site.place
          observation_es_params[:filters] << {
            term: { place_ids: site.place.id }
          }
          identifications_es_params[:filters] << {
            term: { "observation.place_ids": site.place.id }
          }
        else
          observation_es_params[:filters] << {
            term: { site_id: site.id }
          }
          identifications_es_params[:filters] << {
            term: { "observation.site_id": site.id }
          }
        end
      end
      Observation.elastic_search( observation_es_params ).aggregations.users.buckets.each do | bucket |
        activity_counts_by_user[bucket["key"]] ||= {}
        activity_counts_by_user[bucket["key"]][:observations] = bucket["doc_count"]
      end
      Identification.elastic_search( identifications_es_params ).aggregations.users.buckets.each do | bucket |
        activity_counts_by_user[bucket["key"]] ||= {}
        activity_counts_by_user[bucket["key"]][:identifications] = bucket["doc_count"]
      end
      start_id += batch_size
    end
    activity_counts_by_user
  end

  def self.obs_and_id_activity_counts( year, options = {} )
    activity_counts_by_user = user_activity_counts( year, options )
    observed_count = 0
    identified_count = 0
    observed_and_identified_count = 0
    observed_or_identified_count = 0
    activity_counts_by_user.each do | _k, counts |
      observed_or_identified_count += 1
      if counts[:observations] && counts[:identifications]
        observed_and_identified_count += 1
      elsif counts[:observations]
        observed_count += 1
      elsif counts[:identifications]
        identified_count += 1
      end
    end
    {
      only_observed_count: observed_count,
      only_identified_count: identified_count,
      observed_and_identified_count: observed_and_identified_count,
      observed_or_identified_count: observed_or_identified_count
    }
  end

  def self.observation_outlink_counts( year, user, options = {} )
    if options[:debug]
      puts "[#{Time.now}] observation_outlinks, year: #{year}, user: #{user}, options: #{options}"
    end
    return unless user

    es_params = {
      size: 0,
      filters: [{
        term: {
          "user.id": user.id
        }
      }, {
        term: {
          "created_at_details.year": year
        }
      }],
      aggregate: {
        outlinks: {
          terms: {
            field: "outlinks.source",
            size: 10
          }
        }
      }
    }
    Observation.elastic_search( es_params ).aggregations.outlinks.buckets.map do | bucket |
      [bucket["key"], bucket["doc_count"]]
    end.to_h
  end

  def self.run_cmd( cmd, options = { timeout: 60 } )
    Timeout.timeout( options.delete( :timeout ) ) do
      system cmd, options.merge( exception: true )
    end
  end

  def run_cmd( cmd, options = {} )
    self.class.run_cmd( cmd, options )
  end
end
