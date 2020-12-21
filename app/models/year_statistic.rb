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
        month_histogram: observations_histogram( year, options.merge( interval: "month", d1: "1908-01-01" ) ),
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
      },
      translators: translators( year, options )
    }
    if options[:site].blank?
      json[:publications] = publications( year, options )
      json[:growth][:countries] = observation_counts_by_country( year, options )
      json[:budget] = {
        donors: donors( year, options )
      }
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
        streaks: streaks( year, user: user )
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
        observations: observations_histogram_by_created_month( user: user ),
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
    Site.live.find_each do |site|
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
      interval: "day",
      quality_grade: "research,needs_id"
    }.merge( options )
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
    if year >= 2020 && ( user.blank? || user.is_admin? )
      generate_shareable_image_no_obs
    else
      generate_shareable_image_obs_grid
    end
  end

  def generate_shareable_image_obs_grid
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
    medium_font_path = "Lato-Regular" if owner.non_latin_chars?
    light_font_path = "Lato-Light" if title.non_latin_chars?
    if obs_count.to_i > 0
      locale = user.locale if user
      locale ||= site.locale if site
      locale ||= I18n.locale
      obs_text = I18n.t( "x_observations", count: FakeView.number_with_delimiter( obs_count, locale: locale ), locale: locale ).mb_chars.upcase
      medium_font_path = "Lato-Regular" if obs_text.non_latin_chars?
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

  def generate_shareable_image_no_obs
    return unless data && data["observations"]
    work_path = File.join( Dir::tmpdir, "year-stat-#{id}-#{Time.now.to_i}" )
    FileUtils.mkdir_p work_path, mode: 0755
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
    icon_url = icon_url.sub( "staticdev", "static" ) # basically just for testing
    icon_ext = File.extname( URI.parse( icon_url ).path )
    icon_path = File.join( work_path, "icon#{icon_ext}" )
    system "curl -s -o #{icon_path} #{icon_url}"

    # Resize icon to a 500x500 square
    square_icon_path = File.join( work_path, "square_icon.jpg")
    system <<-BASH
      convert #{icon_path} -resize "500x500" \
                        -gravity Center  \
                        -extent 500x500  \
              #{square_icon_path}
    BASH

    final_logo_path = File.join( work_path, "final-logo.png" )
    if user
      # Apply circle mask
      circle_path = File.join( work_path, "circle.png" )
      system "convert -size 500x500 xc:black -fill white -draw \"translate 250,250 circle 0,0 0,250\" -alpha off #{circle_path}"
      system <<-BASH
        convert #{square_icon_path} #{circle_path} \
          -alpha Off -compose CopyOpacity -composite \
          -scale 212x212 \
          #{final_logo_path}
      BASH
    else
      system "convert #{square_icon_path} -resize 212x212 #{final_logo_path}", exception: true
    end

    background_url = "#{FakeView.image_url( "yir-background.png" )}".gsub(/([^\:])\/\//, '\\1/')
    background_path = File.join( work_path, "background.png" )
    system "curl -s -o #{background_path} #{background_url}", exception: true

    left_vertical_offset = if user
      0
    else
      30
    end

    # Overlay the icon onto the montage
    background_with_icon_path = File.join( work_path, "background_with_icon.png" )
    system "composite -gravity northwest -geometry +145+#{left_vertical_offset + 230} #{final_logo_path} #{background_path} #{background_with_icon_path}", exception: true
    wordmark_site = ( user && user.site ) || site || Site.default
    wordmark_url = "#{FakeView.image_url( wordmark_site.logo.url )}".gsub(/([^\:])\/\//, '\\1/')
    wordmark_url = wordmark_url.sub( "staticdev", "static" )
    wordmark_ext = File.extname( URI.parse( wordmark_url ).path )
    wordmark_path = File.join( work_path, "wordmark#{wordmark_ext}" )
    system "curl -s -o #{wordmark_path} #{wordmark_url}"
    wordmark_composite_bg_path = File.join( work_path, "wordmark-composite-bg.png" )
    system "convert -size 500x562 xc:transparent -type TrueColorAlpha #{wordmark_composite_bg_path}", exception: true
    wordmark_resized_path = File.join( work_path, "wordmark-resized.png" )
    system "convert -resize x65 -background none #{wordmark_path} #{wordmark_resized_path}"
    wordmark_composite_path = File.join( work_path, "wordmark-composite.png" )
    wordmark_cmd = <<-BASH
      convert #{wordmark_composite_bg_path} \
        #{wordmark_resized_path} \
        -type TrueColorAlpha \
        -gravity north -geometry +0+#{left_vertical_offset + 70} \
        -composite \
        #{wordmark_composite_path}
    BASH
    system wordmark_cmd, exception: true
    background_icon_wordmark_path = File.join( work_path, "background-icon-wordmark.png" )
    system "convert #{background_with_icon_path} #{wordmark_composite_path} -gravity west -composite #{background_icon_wordmark_path}", exception: true

    # Add the text
    # background_with_icon_and_text_path = File.join( work_path, "background_with_icon_and_text.jpg" )
    light_font_path = File.join( Rails.root, "public", "fonts", "Whitney-Light-Pro.otf" )
    medium_font_path = File.join( Rails.root, "public", "fonts", "Whitney-Medium-Pro.otf" )
    semibold_font_path = File.join( Rails.root, "public", "fonts", "Whitney-Semibold-Pro.otf" )
    final_path = File.join( work_path, "final.jpg" )
    owner = if user
      "@#{user.login}"
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
    obs_count = if data["observations"]["quality_grade_counts"]
      if user
        data["observations"]["quality_grade_counts"]["research"].to_i + data["observations"]["quality_grade_counts"]["needs_id"].to_i
      else
        data["observations"]["quality_grade_counts"].inject( 0 ) {|sum, keyval| sum += keyval[1].to_i }
      end
    else
      0
    end
    species_count = ( data["taxa"] && data["taxa"]["leaf_taxa_count"] ).to_i
    identifications_count = (
      data["identifications"] && data["identifications"]["category_counts"] &&
      data["identifications"]["category_counts"].inject( 0 ) {|sum, keyval| sum += keyval[1].to_i }
    ).to_i

    locale = user.locale if user
    locale ||= site.locale if site
    locale ||= I18n.locale
    label_method = if locale.to_s =~ /^(il|he|ar)/
      "pango"
    else
      "label"
    end
    obs_translation = I18n.t( "x_observations_html",
      count: FakeView.number_with_delimiter( obs_count, locale: locale ),
      locale: locale
    )
    obs_count_txt = obs_translation[/<span.*?>(.+)<\/span>(.+)/, 1].to_s.mb_chars.upcase
    obs_label_txt = obs_translation[/<span.*?>(.+)<\/span>(.+)/, 2].to_s.strip.mb_chars.upcase
    species_translation = I18n.t( "x_species_html",
      count: FakeView.number_with_delimiter( species_count, locale: locale ),
      locale: locale
    )
    species_count_txt = species_translation[/<span.*?>(.+)<\/span>(.+)/, 1].to_s.mb_chars.upcase
    species_label_txt = species_translation[/<span.*?>(.+)<\/span>(.+)/, 2].to_s.strip.mb_chars.upcase
    identifications_translation = I18n.t( "x_identifications_html",
      count: FakeView.number_with_delimiter( identifications_count, locale: locale ),
      locale: locale
    )
    identifications_count_txt = identifications_translation[/<span.*?>(.+)<\/span>(.+)/, 1].to_s.mb_chars.upcase
    identifications_label_txt = identifications_translation[/<span.*?>(.+)<\/span>(.+)/, 2].to_s.strip.mb_chars.upcase
    if [owner, title, species_label_txt, identifications_label_txt, obs_label_txt].detect{|s| s.to_s.non_latin_chars?}
      if Rails.env.production?
        if locale =~ /^(ja|ko|zh)/
          medium_font_path = "Noto-Sans-CJK-HK"
          light_font_path = "Noto-Sans-CJK-HK"
          semibold_font_path = "Noto-Sans-CJK-HK-Bold"
        else
          medium_font_path = "DejaVu-Sans"
          light_font_path = "DejaVu-Sans-ExtraLight"
          semibold_font_path = "DejaVu-Sans-Bold"
        end
      else
        medium_font_path = "Helvetica"
        light_font_path = "Helvetica-Narrow"
        semibold_font_path = "Helvetica-Bold"
      end
    end
    if label_method == "pango"
      title = "<span size='#{1024 * 22}'>#{title}</span>"
      owner = "<span size='#{1024 * 20}'>#{owner}</span>" unless owner.blank?
      obs_count_txt = "<span size='#{1024 * 24}'>#{obs_count_txt}</span>"
      obs_label_txt = "<span size='#{1024 * 20}'>#{obs_label_txt}</span>"
      species_count_txt = "<span size='#{1024 * 24}'>#{species_count_txt}</span>"
      species_label_txt = "<span size='#{1024 * 20}'>#{species_label_txt}</span>"
      identifications_count_txt = "<span size='#{1024 * 24}'>#{identifications_count_txt}</span>"
      identifications_label_txt = "<span size='#{1024 * 20}'>#{identifications_label_txt}</span>"
    end
    title_composite = <<-BASH
      \\( \
        -size 500x30 \
        -background transparent \
        -font #{light_font_path} \
        -kerning 2 \
        #{label_method}:"#{title}" \
        -trim \
        -gravity center \
        -extent 500x30 \
      \\) \
      -gravity northwest \
      -geometry +0+#{left_vertical_offset + 165} \
      -composite
    BASH
    owner_composite = <<-BASH
      \\( \
        -size 500x40 \
        -background transparent \
        -font #{medium_font_path} \
        #{label_method}:"#{owner}" \
        -trim \
        -gravity center \
        -extent 500x40 \
      \\) \
      -gravity northwest \
      -geometry +0+#{left_vertical_offset + 480} \
      -composite
    BASH
    composites = [title_composite]
    composites << owner_composite unless owner.blank?
    [
      [obs_count_txt, obs_label_txt],
      [species_count_txt, species_label_txt],
      [identifications_count_txt, identifications_label_txt]
    ].each_with_index do |texts, idx|
      count_txt, label_txt = texts
      x = 80 + idx * 145
      # text_width = 332 # this would go to the right edge
      text_width = 312 # this provides a bit of margin
      # Note that the use of label below will automatically try to choose the
      # best font size to fit the space
      composites << <<-BASH
        \\( \
          -size #{text_width}x60 \
          -background transparent \
          -font #{semibold_font_path} \
          -fill white \
          #{label_method}:"#{count_txt}" \
          -trim \
          -gravity west \
          -extent #{text_width}x60 \
        \\) \
        -gravity northwest \
        -geometry +668+#{x} \
        -composite \
        \\( \
          -size #{text_width}x34 \
          -background transparent \
          -font #{medium_font_path} \
          -kerning 2 \
          -fill white \
          #{label_method}:"#{label_txt}" \
          -trim \
          -gravity west \
          -extent #{text_width}x34 \
        \\) \
        -gravity northwest \
        -geometry +668+#{x + (148 - 80)} \
        -composite
      BASH
    end
    cmd = <<-BASH
      convert #{background_icon_wordmark_path} \
        #{composites.map(&:strip).join( " \\\n" )} \
        #{final_path}
    BASH
    system cmd, exception: true
    # puts "final_path: #{final_path}"
    self.shareable_image = open( final_path )
    save!
  end

  def self.end_of_month(date)
    n = date + 1.month
    Date.parse( "#{n.year}-#{n.month}-01" ) - 1.day
  end

  def self.observed_species_accumulation( params = { } )
    debug = params.delete(:debug)
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
    bucketer = Proc.new do |es_params|
      buckets = Observation.elastic_search( es_params ).response.aggregations.histogram.buckets
      if debug
        d1_filter = es_params[:filters].detect{|f| f[:range] && f[:range][date_field] && f[:range][date_field][:gte] }
        d2_filter = es_params[:filters].detect{|f| f[:range] && f[:range][date_field] && f[:range][date_field][:lte] }
        if d1_filter && d2_filter
          d1 = Date.parse( d1_filter[:range][date_field][:gte] )
          d2 = Date.parse( d2_filter[:range][date_field][:lte] )
        else
          d1 = Date.parse( "2008-01-01" )
          d2 = Date.today
        end
        bucket_dates = buckets.map{|bucket| bucket["key_as_string"]}.sort
        species_ids = buckets.map {|bucket| bucket.taxon_ids.buckets.map{|b| b["key"].split( "," ).map(&:to_i)} }.flatten.uniq
        puts "observed_species_accumulation results for #{d1} - #{d2}: #{buckets.size} buckets, #{bucket_dates.first} - #{bucket_dates.last}, #{species_ids.size} species"
      end
      buckets
    end

    histogram_buckets = call_and_rescue_with_partitioner(
      bucketer,
      [histogram_params],
      Elasticsearch::Transport::Transport::Errors::ServiceUnavailable,
      exception_checker: Proc.new {|e| e.message =~ /too_many_buckets_exception/ }
    ) do |args|
      es_params = args[0].dup
      d1_filter = es_params[:filters].detect{|f| f[:range] && f[:range][date_field] && f[:range][date_field][:gte] }
      d2_filter = es_params[:filters].detect{|f| f[:range] && f[:range][date_field] && f[:range][date_field][:lte] }
      es_params[:filters] = es_params[:filters].delete_if {|f| f[:range] && f[:range][date_field] }
      if d1_filter && d2_filter
        d1 = Date.parse( d1_filter[:range][date_field][:gte] )
        d2 = Date.parse( d2_filter[:range][date_field][:lte] )
      else
        d1 = Date.parse( "2008-01-01" )
        d2 = YearStatistic.end_of_month( Date.today )
      end
      half = ( d2 - d1 ) / 2
      d1_1 = d1
      d2_1 = YearStatistic.end_of_month( d1 + half.days )
      d1_2 = d2_1 + 1.day
      d2_2 = d2
      es_params1 = es_params.dup
      es_params1[:filters] += [
        { range: { date_field => { gte: d1_1.to_s } } },
        { range: { date_field => { lte: d2_1.to_s } } },
      ]
      es_params2 = es_params.dup
      es_params2[:filters] += [
        { range: { date_field => { gte: d1_2.to_s } } },
        { range: { date_field => { lte: d2_2.to_s } } },
      ]
      new_params = [es_params1, es_params2]
      if debug
        puts "observed_species_accumulation partitions: #{d1_1.to_s} - #{d2_1.to_s}, #{d1_2.to_s} - #{d2_2.to_s}"
      end
      new_params
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
        novel_species_ids: novel_species_ids,
        species_ids: interval_species_ids
      }
      memo
    end
    accumulation_with_all_species_ids.map do |interval|
      {
        date: interval[:date],
        accumulated_species_count: interval[:accumulated_species_ids].size,
        novel_species_ids: interval[:novel_species_ids],
        species_count: interval[:species_ids].size
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
        url = "https://api.altmetric.com/v1/doi/#{doi}"
        begin
          am_response = RestClient.get( url )
          result["altmetric_score"] = JSON.parse( am_response )["score"]
        rescue RestClient::NotFound => e
          Rails.logger.debug "[DEBUG] Request failed for #{url}: #{e}"
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
    if site = options[:user]
      filters << { term: { "user.id" => options[:user].id } }
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
    options = options.clone
    debug = options.delete(:debug)
    streak_length = 5
    ranges = []
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

    streak_bucketer = Proc.new do |query|
      elastic_params = Observation.params_to_elastic_query( query )
      Observation.elastic_search( elastic_params.merge(
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
                  size: 300000
                }
              }
            }
          }
        }
      ) ).response.aggregations.histogram.buckets
    end
    histogram_buckets = call_and_rescue_with_partitioner(
      streak_bucketer,
      base_query,
      Elasticsearch::Transport::Transport::Errors::ServiceUnavailable,
      exception_checker: Proc.new {|e| e.message =~ /too_many_buckets_exception/ }
    ) do |args|
      query = args[0]
      # Assume now one has been on a streak since before 2008-01-01
      puts "partitioning #{query}" if debug
      d1 = query[:d1] && Date.parse( query[:d1] ) || Date.parse( "2008-01-01" )
      d2 = query[:d2] && Date.parse( query[:d2] ) || Date.today
      half = ( d2 - d1 ) / 2
      new_queries = [
        query.merge( d1: d1.to_s, d2: ( d1 + half.days ).to_s ),
        query.merge( d1: ( d1 + (half + 1).days ).to_s, d2: d2.to_s )
      ]
      puts "partitioned into #{new_queries}" if debug
      new_queries
    end
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
      puts "\t#{date}: #{user_ids.size} users, #{finished_user_ids.size} finished" if debug
      finished_user_ids.each do |user_id|
        if debug && options[:user]
          puts "\tFinished streak of length #{current_streaks[user_id]}"
        end
        if current_streaks[user_id] && current_streaks[user_id] >= streak_length
          if debug && options[:user]
            puts "\tAdding streak #{( stop_date + 1.day - ( current_streaks[user_id] ).days )} - #{stop_date}"
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
    return nil if streaks.blank?
    max_stop_date = Date.parse( streaks.map{|s| s[:stop]}.max ) - 2.days
    year_start = Date.parse( "#{year}-01-01" )
    year_stop = Date.parse( "#{year}-12-31" )
    year_range = (year_start..year_stop)
    top_streaks = streaks.select do |s|
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

  def self.translators( year, options = {} )
    return unless CONFIG.crowdin && CONFIG.crowdin.projects
    locale_to_ci_code = {}
    data = { languages: {}, users: {} }
    staff_usernames = User.admins.pluck(:login) + %w(alexinat)
    CONFIG.crowdin.projects.to_h.keys.each do |project_name|
      project = CONFIG.crowdin.projects.send(project_name)
      info_r = RestClient.get( "https://api.crowdin.com/api/project/#{project.identifier}/info?key=#{project.key}&json" )
      info_j = JSON.parse( info_r )
      translated_locales = I18n.t( "locales" ).keys.map(&:to_s)
      languages_by_code = {}
      info_j["languages"].each do |lang|
        unless data[:languages][lang[:name]]
          data[:languages][lang["name"]] = {}
          data[:languages][lang["name"]]["name"] = lang["name"]
          data[:languages][lang["name"]]["code"] = lang["code"]
          if translated_locales.include?( lang["code"] )
            data[:languages][lang["name"]][:locale] = lang["code"]
            locale_to_ci_code[lang["code"]] = lang["code"]
          elsif ( two_letter = lang["code"].split( "-" )[0] ) && translated_locales.include?( two_letter )
            data[:languages][lang["name"]][:locale] = two_letter
            locale_to_ci_code[two_letter] = lang["code"]
          end
        end
      end
      export_params = {
        key: project.key,
        json: true,
        format: "csv",
        date_from: "#{year - 1}-01-01+00:00",
        date_to: "#{year}-12-31+23:00"
      }
      if options[:site] && options[:site].locale
        export_params[:language] = locale_to_ci_code[options[:site].locale]
      end
      export_r = RestClient.post(
        "https://api.crowdin.com/api/project/#{project.identifier}/reports/top-members/export",
        export_params
      )
      export_j = JSON.parse( export_r )
      if export_j["success"]
        report_r = RestClient.get(
          "https://api.crowdin.com/api/project/#{project.identifier}/reports/top-members/download?key=#{project.key}&hash=#{export_j["hash"]}"
        )
        CSV.parse( report_r, headers: true ).each do |row|
          next unless row["Languages"]
          next if staff_usernames.include?( row["Name"] )
          username = row["Name"][/\((.+)\)/, 1]
          next if staff_usernames.include?( username ) 
          languages = row["Languages"].split( ";" ).map(&:strip).select{|l| l !~ /English/}
          next if languages.blank?
          username ||= row["Name"]
          data[:users][username] ||= {}
          data[:users][username][:name] ||= row["Name"].gsub( /\(.+\)/, "" ).strip
          data[:users][username]["words_#{project_name}"] = row["Translated (Words)"].to_i
          data[:users][username]["approved_#{project_name}"] = row["Approved (Words)"].to_i
          data[:users][username][:languages] = languages
        end
      end
    end
    data
  end

  def self.observed_taxa_counts( year, options = {} )
    params = options.merge( year: year, verifiable: true, page: 1 )
    params[:user_id] = options[:user].id if options[:user]
    data = {}
    while true
      puts "Fetching results for #{params}"
      results = INatAPIService.observations_species_counts( params ).results
      break if results.size == 0
      results.each do |r|
        r["taxon"]["ancestor_ids"].each do |tid|
          data[tid] ||= {}
          data[tid][:observations] = data[tid][:observations].to_i + r["count"]
          if r["taxon"]["id"] == tid
            data[tid][:species] = 1
          else
            data[tid][:species] = data[tid][:species].to_i + 1
          end
        end
      end
      params[:page] += 1
    end
    data
  end

  def self.observed_taxa_changes( year, options = {} )
    # final number of top gains and losses to return
    final_cutoff = 30
    this_years_taxa = observed_taxa_counts( year, options )
    last_years_taxa = observed_taxa_counts( year - 1, options )
    all_taxon_ids = ( this_years_taxa.keys + last_years_taxa.keys ).uniq
    # top most observose taxa to derive leaves from. since coarser rank taxa
    # will always have higher counts, the lower this number is the more coarser
    # taxa will be favored
    leaf_cuttoff = [(0.02 * all_taxon_ids.size).ceil, final_cutoff].max
    data = {}
    [:species, :observations].each do |metric|
      deltas = all_taxon_ids.inject({}) do |memo, taxon_id|
        memo[taxon_id] = this_years_taxa[taxon_id].try(:[], metric).to_i - last_years_taxa[taxon_id].try(:[], metric).to_i
        memo
      end
      top_losses = deltas.select{|k,v| v < 0}.sort_by {|k,v| -1 * v.abs}[0..leaf_cuttoff]
      top_gains = deltas.select{|k,v| v > 0}.sort_by {|k,v| -1 * v.abs}[0..leaf_cuttoff]
      top_taxon_ids = (top_losses.map(&:first) + top_gains.map(&:first)).uniq
      taxa = Taxon.where( id: top_taxon_ids ).index_by(&:id)
      losses_ancestor_ids = taxa.fetch_values( *top_losses.map(&:first) ).collect(&:ancestor_ids).flatten.uniq
      top_losses = top_losses.reject{|taxon_id, delta| losses_ancestor_ids.include?( taxon_id ) }[0..final_cutoff]
      gains_ancestor_ids = taxa.fetch_values( *top_gains.map(&:first) ).collect(&:ancestor_ids).flatten.uniq
      top_gains = top_gains.reject{|taxon_id, delta| gains_ancestor_ids.include?( taxon_id ) }[0..final_cutoff]
      final_taxon_ids = (top_losses.map(&:first) + top_gains.map(&:first)).uniq
      data[metric] = final_taxon_ids.collect do |taxon_id|
        taxon = taxa[taxon_id]
        {
          taxon: taxon.as_indexed_json( no_details: true ).keep_if {|k,v|
            [:id, :name, :rank, :rank_level, :default_photo, :is_active].include?( k )
          }.merge(
            iconic_taxon_name: taxon.iconic_taxon_name,
            preferred_common_name: taxon.common_name( user: options[:user] ).try(:name)
          ),
          delta: deltas[taxon_id]
        }
      end
    end
    data
  end

  def self.donors( year, options = {} )
    options = options.clone
    debug = options.delete(:debug)
    limit = options.delete(:limit)
    donorbox_email = CONFIG.donorbox.email
    donorbox_key = CONFIG.donorbox.key
    return if donorbox_key.blank?
    page = 1
    per_page = 100
    donations = []
    donation_encountered = {}
    while true
      break if limit && donations.size >= limit
      url = "https://donorbox.org/api/v1/donations?page=#{page}&per_page=#{per_page}"
      puts "Fetching #{url}" if debug
      response = RestClient.get( url, {
        "Authorization" => "Basic #{Base64.strict_encode64( "#{donorbox_email}:#{donorbox_key}" ).strip}",
        "User-Agent" => "iNaturalist/Donorbox"
      } )
      json = JSON.parse( response )
      puts "Received #{json.size} donations" if debug
      break if json.size == 0
      page_donations = json.select{|d| DateTime.parse( d["donation_date"] ).year == year }
      puts "Received #{page_donations.size} donations for #{year}" if debug
      if page_donations.size == 0
        break
      end
      page_donations.each do |d|
        next if d["amount_refunded"].to_f > 0
        next unless d["status"] == "paid"
        next if donation_encountered[d["id"]]
        donation_encountered[d["id"]] = true
        net_amount_usd = d["converted_net_amount"] || d["converted_amount"] || d["amount"]
        next unless net_amount_usd
        donations << {
          # net_amount_usd: net_amount_usd.to_f,
          date: Date.parse( d["donation_date"] ),
          donor_id: d["donor"]["id"],
          recurring: d["recurring"],
          # monthly: d["campaign"] && d["campaign"]["name"].to_s =~ /Monthly Support/
        }
      end
      puts "#{donations.size} total donations for #{year} so far" if debug
      page += 1
    end
    puts "Received #{donations.size} total donations" if debug
    monthly = donations.inject( {} ) do |memo, d|
      key = d[:date].strftime( "%Y-%m-01" )
      memo[key] ||= {}
      # memo[key][:total_net_amount_usd] = memo[key][:total_net_amount_usd].to_f + d[:net_amount_usd]
      memo[key][:total_donors] ||= Set.new
      memo[key][:total_donors] << d[:donor_id]
      if d[:recurring]
        # memo[key][:recurring_net_amount_usd] = memo[key][:recurring_net_amount_usd].to_f + d[:net_amount_usd]
        memo[key][:recurring_donors] ||= Set.new
        memo[key][:recurring_donors] << d[:donor_id]
      end
      # if d[:monthly]
      #   memo[key][:monthly_net_amount_usd] = memo[key][:monthly_net_amount_usd].to_f + d[:net_amount_usd]
      #   memo[key][:monthly_donors] ||= Set.new
      #   memo[key][:monthly_donors] << d[:donor_id]
      # end
      memo
    end
    data = monthly.keys.sort.map do |key|
      d = monthly[key]
      {
        date: key,
        # total_net_amount_usd: d[:total_net_amount_usd],
        total_donors: d[:total_donors].size,
        # recurring_net_amount_usd: d[:recurring_net_amount_usd],
        recurring_donors: d[:recurring_donors].size,
        # monthly_net_amount_usd: d[:monthly_net_amount_usd],
        # monthly_donors: d[:monthly_donors].size
      }
    end
  end

  # Maximum distance in meters between obs created by a single user for each
  # month of the year. Calculates pairwise comparisons between all obs made by
  # the user in that month so it's pretty slow.
  def max_obs_distances_for_user( year, user )
    data = []
    ( 1..12 ).each do |month|
      d1 = Date.new( year, month )
      d2 = d1.end_of_month
      sql = <<-SQL
        SELECT
          o1.id,
          o2.id,
          ST_DistanceSphere(o1.private_geom, o2.private_geom) AS distance
        FROM
          observations o1,
          observations o2
        WHERE
          o1.user_id = #{user.id}
          AND o2.user_id = #{user.id}
          AND o1.id != o2.id
          AND o1.geom IS NOT NULL
          AND o2.geom IS NOT NULL
          AND o1.observed_on BETWEEN '#{d1.to_s}' AND '#{d2.to_s}'
          AND o2.observed_on BETWEEN '#{d1.to_s}' AND '#{d2.to_s}'
        ORDER BY distance DESC
        LIMIT 1
      SQL
      r = ActiveRecord::Base.connection.execute( sql )
      data << [d1.to_s, (r && r.count > 0 ? r[0]["distance"] : 0).to_f]
    end
    # CSV(STDOUT) do |csv|
    #   csv << %w(date distance)
    #   data.each do |row|
    #     csv << row
    #   end
    # end
    data
  end

  # Stats on maximum distance in meters between obs created by all users for
  # each month of the year. Instead of pairwise comparisons, this just
  # calculates the bounding box for each user's observations within a month and
  # uses the box's diagonal as the "distance," so it's just an approximation.
  def est_max_obs_distances( year, options = {} )
    debug = options.clone.delete(:debug)
    data = []
    ( 1..12 ).each do |month|
      d1 = Date.new( year, month )
      d2 = d1.end_of_month
      params = { geo: true, d1: d1.to_s, d2: d2.to_s }
      elastic_params = Observation.params_to_elastic_query( params )
      geo_bounds_params = elastic_params.merge(
        size: 0,
        track_total_hits: true,
        aggs: {
          user_ids: {
            terms: {
              field: "user.id",
              size: 300000
            },
            aggs: {
              bounding_box: {
                geo_bounds: {
                  field: "private_location"
                }
              }
            }
          }
        }
      )
      distances = []
      buckets = Observation.elastic_search( geo_bounds_params ).response.aggregations.user_ids.buckets
      puts "#{d1}, calculating distances for #{buckets.size} users..." if debug
      buckets.buckets.each do |bucket|
        next unless bucket.bounding_box && bucket.bounding_box.bounds
        next if bucket.doc_count <= 1
        d = lat_lon_distance_in_meters(
          bucket.bounding_box.bounds.bottom_right.lat,
          bucket.bounding_box.bounds.bottom_right.lon,
          bucket.bounding_box.bounds.top_left.lat,
          bucket.bounding_box.bounds.top_left.lon
        )
        next if d == 0
        distances << d
      end
      data << {
        date: d1.to_s,
        avg: distances.sum / distances.size.to_f,
        med: distances.median,
        # min: distances.min,
        # max: distances.max
      }
    end
    # headers = data[0].keys
    # CSV(STDOUT) do |csv|
    #   csv << headers
    #   data.each do |row|
    #     csv << headers.map{|h| row[h] }
    #   end
    # end
    data
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
