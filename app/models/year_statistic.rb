class YearStatistic < ActiveRecord::Base
  belongs_to :user
  belongs_to :site

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
    if options[:site]
      year_statistic = year_statistic.where( site_id: options[:site] )
    else
      year_statistic = year_statistic.where( "site_id IS NULL" )
    end
    year_statistic = year_statistic.first_or_create
    json = {
      observations: {
        quality_grade_counts: obervation_counts_by_quality_grade( year, options ),
        month_histogram: observations_histogram( year, options.merge( interval: "month" ) ),
        week_histogram: observations_histogram( year, options.merge( interval: "week" ) ),
        day_histogram: observations_histogram( year, options.merge( interval: "day" ) ),
        day_last_year_histogram: observations_histogram( year - 1, options.merge( interval: "day" ) ),
        popular: popular_observations( year, options ),
        streaks: streaks( year, options )
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
          site: options[:site],
          verifiable: true
        )
      },
      growth: {
        observations: observations_histogram_by_created_month( options ),
        users: users_histogram_by_created_month( options )
      }
    }
    if options[:site].blank?
      json[:publications] = publications( year, options )
      json[:growth][:countries] = observation_counts_by_country( year, options )
    end
    year_statistic.update_attributes( data: json )
    year_statistic.delay( priority: USER_PRIORITY ).generate_shareable_image
    year_statistic
  end

  # Generates stats for a specific network site for a single year
  def self.generate_for_site_year( site, year )
    generate_for_year( year, { site: site } )
  end

  # Generates stats for a specific user for a single year
  def self.generate_for_user_year( user, year )
    user = user.is_a?( User ) ? user : User.find_by_id( user )
    return unless user
    year_statistic = YearStatistic.where( year: year ).where( user_id: user ).first_or_create
    accumulation = observed_species_accumulation(
      user: user,
      verifiable: true
    )
    users_who_helped_arr, total_users_who_helped, total_ids_received = users_who_helped( year, user )
    users_helped_arr, total_users_helped, total_ids_given = users_helped( year, user )
    json = {
      observations: {
        quality_grade_counts: obervation_counts_by_quality_grade( year, user: user ),
        month_histogram: observations_histogram( year, user: user, interval: "month" ),
        week_histogram: observations_histogram( year, user: user, interval: "week" ),
        day_histogram: observations_histogram( year, user: user, interval: "day" ),
        day_last_year_histogram: observations_histogram( year - 1, user: user, interval: "day" ),
        popular: popular_observations( year, user: user )
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
        iconic_taxon_counts: identification_counts_by_iconic_taxon( year, user )
      },
      taxa: {
        leaf_taxa_count: leaf_taxa_count( year, user: user ),
        iconic_taxa_counts: iconic_taxa_counts( year, user: user ),
        tree_taxa: tree_taxa( year, user: user ),
        accumulation: accumulation
      }
    }
    year_statistic.update_attributes( data: json )
    year_statistic.delay( priority: USER_PRIORITY ).generate_shareable_image
    year_statistic
  end

  def self.regenerate_existing
    YearStatistic.find_each do |ys|
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
    generate_for_year( year )
    Site.find_each do |site|
      next if Site.default && Site.default.id == site.id
      generate_for_site_year( site, year )
    end
  end

  def self.tree_taxa( year, options = {} )
    params = { year: year }
    if user = options[:user]
      params[:user_id] = user.id
    end
    if site = options[:site]
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    if user
      if place = user.place || user.site.try(:place)
        params[:preferred_place_id] = place.id
      end
      if locale = user.locale || user.site.try(:locale)
        params[:locale] = locale
      end
    elsif site
      if place = site.place
        params[:preferred_place_id] = place.id
      end
      if locale = site.locale
        params[:locale] = locale
      end
    end
    JSON.parse( INatAPIService.get_json("/observations/tree_taxa", params, { timeout: 30 } ) )["results"] rescue nil
  end

  def self.observations_histogram( year, options = {} )
    params = {
      d1: "#{year}-01-01",
      d2: "#{year}-12-31",
      interval: options[:interval] || "day",
      quality_grade: options[:quality_grade] || "research,needs_id"
    }
    if user = options[:user]
      params[:user_id] = user.id
    end
    if site = options[:site]
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    JSON.parse( INatAPIService.get_json("/observations/histogram", params, { timeout: 30 } ) )["results"][params[:interval]]
  end

  def self.identifications_histogram( year, options = {} )
    interval = options[:interval] || "day"
    es_params = YearStatistic.identifications_es_base_params( year ).merge(
      aggregate: {
        histogram: {
          date_histogram: {

            field: "created_at",
            interval: interval,
            format: "yyyy-MM-dd"
          }
        }
      }
    )
    if options[:user]
      es_params[:filters] << { terms: { "user.id": [options[:user].id] } }
    end
    if site = options[:site]
      if site.place
        es_params[:filters] << { terms: { "observation.place_ids": [site.place.id] } }
      else
        es_params[:filters] << { terms: { "observation.site_id": [site.id] } }
      end
    end
    histogram = {}
    Identification.elastic_search( es_params ).response.aggregations.histogram.buckets.each {|b|
      histogram[b.key_as_string] = b.doc_count
    }
    histogram
  end

  def self.identification_counts_by_category( year, options = {} )
    es_params = YearStatistic.identifications_es_base_params( year ).merge(
      aggregate: {
        categories: { terms: { field: "category" } }
      }
    )
    if options[:user]
      es_params[:filters] << { terms: { "user.id": [options[:user].id] } }
    end
    if site = options[:site]
      if site.place
        es_params[:filters] << { terms: { "observation.place_ids": [site.place.id] } }
      else
        es_params[:filters] << { terms: { "observation.site_id": [site.id] } }
      end
    end
    Identification.elastic_search( es_params ).response.aggregations.categories.buckets.inject({}) do |memo, bucket|
      memo[bucket["key"]] = bucket.doc_count
      memo
    end
  end

  def self.identification_counts_by_iconic_taxon( year, user )
    return unless user
    es_params = identifications_es_base_params( year )
    es_params[:filters] << { terms: { "user.id" => [user.id] } }
    es_params[:aggregate] = {
      iconic_taxa: { terms: { field: "taxon.iconic_taxon_id" } }
    }
    Identification.elastic_search( es_params ).response.aggregations.iconic_taxa.buckets.inject({}) do |memo, bucket|
      # memo[bucket["key"]] = bucket.doc_count
      # memo
      key = Taxon::ICONIC_TAXA_BY_ID[bucket["key"].to_i].try(:name)
      memo[key] = bucket.doc_count
      memo
    end
  end

  def self.obervation_counts_by_quality_grade( year, options = {} )
    params = { year: year }
    params[:user_id] = options[:user].id if options[:user]
    if site = options[:site]
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
    ) ).response.aggregations.quality_grades.buckets.inject({}) do |memo, bucket|
      memo[bucket["key"]] = bucket.doc_count
      memo
    end
  end

  def self.leaf_taxa_count( year, options = {} )
    params = { year: year, verifiable: true }
    params[:user_id] = options[:user].id if options[:user]
    if site = options[:site]
      if site.place
        params[:place_id] = site.place.id
      else
        params[:site_id] = site.id
      end
    end
    # Observation.elastic_taxon_leaf_counts( Observation.params_to_elastic_query( params ) ).size
    JSON.parse( INatAPIService.get_json( "/observations/species_counts", params, { timeout: 30 } ) )["total_results"].to_i
  end

  def self.iconic_taxa_counts( year, options = {} )
    params = { year: year, verifiable: true }
    params[:user_id] = options[:user].id if options[:user]
    if site = options[:site]
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
    ) ).response.aggregations.iconic_taxa.buckets.inject({}) do |memo, bucket|
      key = Taxon::ICONIC_TAXA_BY_ID[bucket["key"].to_i].try(:name)
      memo[key] = bucket.doc_count
      memo
    end
  end

  def self.popular_observations( year, options = {} )
    params = options.merge( year: year, has_photos: true, verifiable: true )
    if user = params.delete(:user)
      params[:user_id] = user.id
    end
    if site = params.delete(:site)
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
        { "faves_count": "desc" },
        { "comments_count": "desc" }
      ]
    )
    r = Observation.elastic_search( es_params_with_sort ).per_page( 200 ).response
    ids = r.hits.hits.map{|h| h._source.id }
    api_params = {
      id: ids,
      per_page: 200
    }
    if user
      if place = user.place || user.site.try(:place)
        api_params[:preferred_place_id] = place.id
      end
      if locale = user.locale || user.site.try(:locale)
        api_params[:locale] = locale
      end
    elsif site
      if place = site.place
        api_params[:preferred_place_id] = place.id
      end
      if locale = site.locale
        api_params[:locale] = locale
      end
    end
    return [] if ids.blank?
    response = INatAPIService.get_json( "/observations", api_params, { timeout: 30 } )
    json = JSON.parse( response )
    json["results"].
        sort_by{|o| [0 - o["faves_count"].to_i, 0 - o["comments_count"].to_i] }.
        each_with_index.map do |o,i|
      json_obs = {
        id: o["id"]
      }
      if !o["photos"].blank?
        json_obs[:photos] = [o["photos"][0].select{|k,v| %w(url original_dimensions).include?( k ) }]
      end
      if i < 36
        json_obs = json_obs.merge( o.select{|k,v| %w{comments_count faves_count observed_on}.include?( k ) })
        json_obs[:user] = o["user"].select{|k,v| %{id login name icon_url}.include?( k )}
        if o["taxon"]
          json_obs[:taxon] = o["taxon"].select{|k,v| %{id name rank preferred_common_name}.include?( k )}
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
      users_helped: { terms: { field: "observation.user_id", size: 40000 } },
    }
    buckets = Identification.
      elastic_search( es_params ).
      response.
      aggregations.
      users_helped.
      buckets
    users = buckets[0..2].inject( [] ) do |memo, bucket|
      if helped_user = User.find_by_id( bucket["key"] )
        memo << {
          count: bucket.doc_count,
          user: helped_user.as_indexed_json
        }
      end
      memo
    end.compact
    [users, buckets.size, buckets.map(&:doc_count).sum]
  end

  def self.users_who_helped( year, user )
    return unless user
    es_params = YearStatistic.identifications_es_base_params( year )
    es_params[:filters] << { terms: { "observation.user_id" => [user.id] } }
    es_params[:aggregate] = {
      users_helped: { terms: { field: "user.id", size: 40000 } }
    }
    buckets = Identification.
      elastic_search( es_params ).
      response.
      aggregations.
      users_helped.
      buckets
    users = buckets[0..2].inject( [] ) do |memo, bucket|
      helped_user = User.find_by_id( bucket["key"] )
      next unless helped_user
      memo << {
        count: bucket.doc_count,
        user: helped_user.as_indexed_json
      }
      memo
    end.compact
    [users, buckets.size, buckets.map(&:doc_count).sum]
  end

  def generate_shareable_image
    return unless data && data["observations"] && data["observations"]["popular"]
    return if data["observations"]["popular"].size == 0
    work_path = File.join( Dir::tmpdir, "year-stat-#{id}-#{Time.now.to_i}" )
    FileUtils.mkdir_p work_path, mode: 0755
    image_urls = data["observations"]["popular"].map{|o| o["photos"].try(:[], 0).try(:[], "url")}.compact
    return if image_urls.size == 0
    target_size = 200
    while image_urls.size < target_size
      image_urls += image_urls
    end
    image_urls = image_urls[0...target_size]

    # Make the montage
    image_urls.each_with_index do |url, i|
      ext = File.extname( URI.parse( url ).path )
      outpath = File.join( work_path, "photo-#{i}#{ext}" )
      system "curl -s -o #{outpath} #{url}"
    end
    inpaths = File.join( work_path, "photo-*" )
    montage_path = File.join( work_path, "montage.jpg" )
    system "montage #{inpaths} -tile 20x -geometry 50x50+0+0 #{montage_path}"

    # Get the icon
    icon_url = if user
      "#{FakeView.image_url( user.icon.url(:large) )}".gsub(/([^\:])\/\//, '\\1/')
    elsif site
      "#{FakeView.image_url( site.logo_square.url )}".gsub(/([^\:])\/\//, '\\1/')
    elsif Site.default
      "#{FakeView.image_url( Site.default.logo_square.url )}".gsub(/([^\:])\/\//, '\\1/')
    else
      "#{FakeView.image_url( "bird.png" )}".gsub(/([^\:])\/\//, '\\1/')
    end
    icon_ext = File.extname( URI.parse( icon_url ).path )
    icon_path = File.join( work_path, "icon#{icon_ext}" )
    system "curl -s -o #{icon_path} #{icon_url}"

    # Resize icon to a 500x500 square
    square_icon_path = File.join( work_path, "square_icon.jpg")
    system <<-BASH
      convert #{icon_path} -resize "500x500^" \
                        -gravity Center  \
                        -extent 500x500  \
              #{square_icon_path}
    BASH

    # Apply circle mask and white border
    circle_path = File.join( work_path, "circle.png" )
    system "convert -size 500x500 xc:black -fill white -draw \"translate 250,250 circle 0,0 0,250\" -alpha off #{circle_path}"
    circle_icon_path = File.join( work_path, "circle-user-icon.png" )
    system <<-BASH
      convert #{square_icon_path} #{circle_path} \
        -alpha Off -compose CopyOpacity -composite \
        -stroke white -strokewidth 20 -fill transparent -draw "translate 250,250 circle 0,0 0,240" \
        -scale 50% \
        #{circle_icon_path}
    BASH

    # Apply mask to the montage
    ellipse_mask_path = File.join( work_path, "ellipse_mask.png" )
    system "convert -size 1000x500 radial-gradient:\"#ccc\"-\"#111\" #{ellipse_mask_path}"
    ellipse_montage_path = File.join( work_path, "ellipse_montage.jpg" )
    system <<-BASH
      convert #{montage_path} #{ellipse_mask_path} \
        -alpha Off -compose multiply -composite\
        #{ellipse_montage_path}
    BASH

    # Overlay the icon onto the montage
    montage_with_icon_path = File.join( work_path, "montage_with_icon.jpg" )
    system "composite -gravity center #{circle_icon_path} #{ellipse_montage_path} #{montage_with_icon_path}"

    # Add the text
    montage_with_icon_and_text_path = File.join( work_path, "montage_with_icon_and_text.jpg" )
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
      data["observations"]["quality_grade_counts"]["research"].to_i + data["observations"]["quality_grade_counts"]["needs_id"].to_i
    rescue
      nil
    end
    if obs_count.to_i > 0
      locale = user.locale if user
      locale ||= site.locale if site
      locale ||= I18n.locale
      obs_text = I18n.t( "x_observations", count: FakeView.number_with_delimiter( obs_count, locale: locale ), locale: locale ).mb_chars.upcase
      system <<-BASH
        convert #{montage_with_icon_path} \
          -fill white -font #{medium_font_path} -pointsize 24 -gravity north -annotate 0x0+0+30 "#{owner}" \
          -fill white -font #{light_font_path} -pointsize 65 -gravity north -annotate 0x0+0+60 "#{title}" \
          -fill white -font #{medium_font_path} -pointsize 46 -gravity south -annotate 0x0+0+50 "#{obs_text}" \
          #{final_path}
      BASH
    else
      system <<-BASH
        convert #{montage_with_icon_path} \
          -fill white -font #{medium_font_path} -pointsize 24 -gravity north -annotate 0x0+0+30 "#{owner}" \
          -fill white -font #{light_font_path} -pointsize 65 -gravity north -annotate 0x0+0+60 "#{title}" \
          #{final_path}
      BASH
    end

    self.shareable_image = open( final_path )
    save!
  end

  def self.observed_species_accumulation( params = { } )
    interval = params.delete(:interval) || "month"
    date_field = params.delete(:date_field) || "created_at"
    params[:user_id] = params[:user].id if params[:user]
    params[:quality_grade] =  params[:quality_grade] || "research,needs_id"
    if site = params[:site]
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
            interval: interval,
            format: "yyyy-MM-dd"
          },
          aggs: {
            taxon_ids: {
              terms: { field: "taxon.min_species_ancestry", size: 100000 }
            }
          }
        }
      }
    )
    histogram_buckets = if params[:user_id] || params[:taxon_id]
      Observation.elastic_search( histogram_params ).response.aggregations.histogram.buckets
    else
      # If we're not scoping this query by something that will keep the counts
      # reasonable, we need to break this into pieces
      [
        ["2008-01-01", "2014-01-01"],
        ["2014-01-01", "2016-01-01"],
        ["2016-01-01", "2017-01-01"],
        ["2017-01-01", "2017-06-01"],
        ["2017-06-01", "2018-01-01"],
        ["2018-01-01", "2018-06-01"],
        ["2018-06-01", "2019-01-01"],
        ["2019-01-01", "2019-06-01"],
        ["2019-06-01", "2019-10-01"],
        ["2019-10-01", "2020-01-01"]
      ].inject( [] ) do |memo, range|
        puts "range: #{range.join( " - " )}"
        es_params = histogram_params.dup
        es_params[:filters] += [
          { range: { date_field => { gte: range[0] } } },
          { range: { date_field => { lt: range[1] } } },
        ]
        memo += Observation.elastic_search( es_params ).response.aggregations.histogram.buckets
        memo
      end
    end

    accumulation_with_all_species_ids = histogram_buckets.each_with_index.inject([]) do |memo, pair|
      bucket, i = pair
      interval_species_ids = bucket.taxon_ids.buckets.map{|b| b["key"].split( "," ).map(&:to_i)}.flatten.uniq
      interval_species_ids = Taxon.where( id: interval_species_ids, rank: Taxon::SPECIES ).pluck(:id)
      accumulated_species_ids = if i > 0 && memo[i-1]
        memo[i-1][:accumulated_species_ids]
      else
        []
      end
      novel_species_ids = interval_species_ids - accumulated_species_ids
      memo << {
        date: bucket["key_as_string"],
        accumulated_species_ids: accumulated_species_ids + novel_species_ids,
        novel_species_ids: novel_species_ids
      }
      memo
    end
    accumulation_with_all_species_ids.map do |interval|
      {
        date: interval[:date],
        accumulated_species_count: interval[:accumulated_species_ids].size,
        novel_species_ids: interval[:novel_species_ids]
      }
    end
  end

  def self.publications( year, options )
    gbif_endpont = "https://www.gbif.org/api/resource/search"
    gbif_params = {
      contentType: "literature",
      # iNat RG Observations dataset identifier on GBIF We don't publish site-
      # specific datasets, so there's no reason not to hard-code it here.
      gbifDatasetKey: "50c9509d-22c7-4a22-a47d-8c48425ef4a7",
      literatureType: "journal",
      year: year,
      limit: 50
    }
    data = JSON.parse( RestClient.get( "#{gbif_endpont}?#{gbif_params.to_query}" ) )
    new_results = []
    data["results"].each do |result|
      if doi = result["identifiers"] && result["identifiers"]["doi"]
        begin
          am_response = RestClient.get( "https://api.altmetric.com/v1/doi/#{doi}" )
          result["altmetric_score"] = JSON.parse( am_response )["score"]
        rescue RestClient::NotFound => e
          Rails.logger.debug "[DEBUG] Request failed: #{e}"
        end
        sleep( 1 )
      end
      result["_gbifDOIs"] = result["_gbifDOIs"][0..9]
      new_results << result.slice(
        "title",
        "authors",
        "year",
        "source",
        "websites",
        "publisher",
        "id",
        "identifiers",
        "_gbifDOIs",
        "altmetric_score"
      )
    end
    data["results"] = new_results.sort_by{|r| r["altmetric_score"].to_f * -1 }[0..5]
    data[:url] = "https://www.gbif.org/resource/search?#{gbif_params.to_query}"
    data
  end

  def self.observations_histogram_by_created_month( options = {} )
    filters = [
      { terms: { "quality_grade": ["research", "needs_id"] } }
    ]
    if site = options[:site]
      if site.place
        filters << { terms: { place_ids: [site.place.id] } }
      else
        filters << { terms: { site_id: [site.id] } }
      end
    end
    es_params = {
      size: 0,
      filters: filters,
      aggregate: {
        histogram: {
          date_histogram: {
            field: "created_at_details.date",
            interval: "month",
            format: "yyyy-MM-dd"
          }
        }
      }
    }
    histogram = {}
    Observation.elastic_search( es_params ).response.aggregations.histogram.buckets.each {|b|
      histogram[b.key_as_string] = b.doc_count
    }
    histogram
  end

  def self.users_histogram_by_created_month( options  = {} )
    scope = User.group( "EXTRACT('year' FROM created_at) || '-' || EXTRACT('month' FROM created_at)" ).
      where( "suspended_at IS NULL AND created_at > '2008-03-01' AND observations_count > 0" )
    if site = options[:site]
      scope = scope.where( "site_id = ?", site )
    end
    Hash[scope.count.map do |k,v|
      ["#{k.split( "-" ).map{|s| s.rjust( 2, "0" )}.join( "-" )}-01", v]
    end.sort]
  end

  def self.observation_counts_by_country( year, params = {} )
    data = Place.where( admin_level: 0 ).all.inject( [] ) do |memo, p|
      r = INatAPIService.observations( per_page: 0, verifiable: true,
        created_d1: "#{year}-01-01",
        created_d2: "#{year}-12-31",
        place_id: p.id
      )
      year_count = r ? r.total_results : 0
      r = INatAPIService.observations( per_page: 0, verifiable: true,
        created_d1: "#{year - 1}-01-01",
        created_d2: "#{year - 1}-12-31",
        place_id: p.id
      )
      last_year_count = r ? r.total_results : 0
      if year_count.to_i <= 0
        memo
      else
        memo << {
          place_id: p.id,
          place_code: p.code,
          place_bounding_box: p.bounding_box,
          name: p.name,
          observations: year_count,
          observations_last_year: last_year_count
        }
        memo
      end
    end
  end

  def self.streaks( year, options = {} )
    streak_length = 5
    ranges = []
    base_query = { quality_grade: "research,needs_id" }
    if options[:site]
      base_query = base_query.merge( site_id: options[:site].id )
    end
    if options[:user]
      ranges = [["#{year}-01-01", "#{year}-12-31"]]
      base_query = base_query.merge( user_id: options[:user].id )
    else
      ranges = [
        ["2008-01-01", "2013-12-31"],
        ["2014-01-01", "2014-12-31"],
        ["2015-01-01", "2015-12-31"],
        ["2016-01-01", "2016-12-31"]
      ]
      [2017, 2018, 2019].each do |y|
        chunks = 10
        interval = ( 365.0 / chunks ).floor
        d0 = Date.parse( "#{y}-01-01" )
        d1 = d0
        while true
          d2 = d1 + interval.days
          if d2 >= ( d0 + 1.year )
            ranges << [d1.to_s, "#{y}-12-31"]
            break
          end
          ranges << [d1.to_s, d2.to_s]
          d1 = d2 + 1.day
        end
      end
    end
    streaks = []
    current_streaks = {}
    previous_user_ids = []
    ranges.each_with_index do |range, range_i|
      puts "range: #{range}"
      elastic_params = Observation.params_to_elastic_query( base_query.merge( d1: range[0], d2: range[1] ) )
      histogram_buckets = Observation.elastic_search( elastic_params.merge(
        size: 0,
        aggs: {
          histogram: {
            date_histogram: {
              field: "observed_on",
              calendar_interval: "day",
              format: "yyyy-MM-dd"
            },
            aggs: {
              user_ids: {
                terms: {
                  field: "user.id",
                  size: 30000
                }
              }
            }
          }
        }
      ) ).response.aggregations.histogram.buckets
      histogram_buckets.each_with_index do |bucket, bucket_i|
        date = bucket["key_as_string"]
        user_ids = bucket.user_ids.buckets.map{|b| b["key"].to_i}
        user_ids.each do |streaking_user_id|
          current_streaks[streaking_user_id] ||= 0
          current_streaks[streaking_user_id] += 1
        end

        # Finished users are all the users who were present in the previous day
        # but not in this one. For each of these, we need to add their streaks
        # with the stop date set to the previous day
        stop_date = ( Date.parse( date ) - 1.day )
        finished_user_ids = []
        finished_user_ids = previous_user_ids - user_ids
        puts "\t#{date}: #{user_ids.size} users, #{finished_user_ids.size} finished"
        finished_user_ids.each do |user_id|
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

        # If this is the final day and there are still streaks in progress, we
        # need to add their streaks with the stop today set to *this* day
        if bucket_i == ( histogram_buckets.size - 1 ) && range_i == ( ranges.size - 1 )
          streaking_user_ids = current_streaks.keys
          stop_date = Date.parse( date )
          streaking_user_ids.each do |user_id|
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
    end
    return nil if streaks.blank?
    max_stop_date = Date.parse( streaks.map{|s| s[:stop]}.max ) - 2.days
    top_streaks = streaks.select do |s|
      Date.parse( s[:stop] ) >= max_stop_date ||
        Date.parse( s[:start]) >= Date.parse( "#{year}-01-01" )
    end
    top_streaks = top_streaks.sort_by{|s| s[:days] * -1}[0..100]
    top_streaks_user_ids = top_streaks.map{|u| u[:user_id]}
    top_streaks_users = User.where( id: top_streaks_user_ids )
    top_streaks = top_streaks.map do |s|
      u = top_streaks_users.detect{|u| u.id == s[:user_id]}
      if u.suspended?
        nil
      else
        s.merge(
          login: u.login,
          icon_url: "#{FakeView.image_url( u.icon.url(:medium) )}".gsub( /([^\:])\/\//, '\\1/' )
        )
      end
    end.compact
    top_streaks
  end

  private
  def self.identifications_es_base_params( year )
    {
      size: 0,
      filters: [
        { range: { "created_at": { gte: "#{year}-01-01" } } },
        { range: { "created_at": { lte: "#{year}-12-31" } } },
        { terms: { "own_observation": [false] } },
        { terms: { "observation.quality_grade": ["research", "needs_id"] } },
        { terms: { "current": [true] } }
      ],
      inverse_filters: [
        { exists: { field: "taxon_change_id" } }
      ]
    }
  end

end
