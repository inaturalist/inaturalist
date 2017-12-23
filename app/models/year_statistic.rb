class YearStatistic < ActiveRecord::Base
  belongs_to :user
  belongs_to :site

  if Rails.env.production?
    has_attached_file :shareable_image,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
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
        iconic_taxa_counts: iconic_taxa_counts( year, options )
      }
    }
    year_statistic.update_attributes( data: json )
    year_statistic.delay( priority: USER_PRIORITY ).generate_shareable_image
    year_statistic
  end

  def self.generate_for_site_year( site, year )
    generate_for_year( year, { site: site } )
  end

  def self.generate_for_user_year( user, year )
    user = user.is_a?( User ) ? user : User.find_by_id( user )
    return unless user
    year_statistic = YearStatistic.where( year: year ).where( user_id: user ).first_or_create
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
        day_histogram: identifications_histogram( year, user: user, interval: "day" )
      },
      taxa: {
        leaf_taxa_count: leaf_taxa_count( year, user: user ),
        iconic_taxa_counts: iconic_taxa_counts( year, user: user ),
        tree_taxa: tree_taxa( year, user: user )
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

  def self.tree_taxa( year, options = {} )
    params = { year: year }
    if user = options[:user]
      params[:user_id] = user.id
    end
    if site = options[:site]
      params[:site_id] = site.id
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
    JSON.parse( INatAPIService.get_json("/observations/tree_taxa", params, 3, 30 ) )["results"] rescue nil
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
      params[:site_id] = site.id
    end
    JSON.parse( INatAPIService.get_json("/observations/histogram", params, 3, 30 ) )["results"][params[:interval]]
  end

  def self.identifications_histogram( year, options = {} )
    interval = options[:interval] || "day"
    es_params = {
      size: 0,
      filters: [
        { terms: { "created_at_details.year": [year] } },
        { terms: { "own_observation": [false] } },
        { terms: { "observation.quality_grade": ["research", "needs_id"] } },
        { terms: { "current": [true] } }
      ],
      inverse_filters: [
        { exists: { field: "taxon_change_id" } }
      ],
      aggregate: {
        histogram: {
          date_histogram: {
            field: "created_at_details.date",
            interval: interval,
            format: "yyyy-MM-dd"
          }
        }
      }
    }
    if options[:user]
      es_params[:filters] << { terms: { "user.id": [options[:user].id] } }
    end
    if site = options[:site]
      es_params[:filters] << { terms: { "observation.site_id": [site.id] } }
    end
    histogram = {}
    Identification.elastic_search( es_params ).response.aggregations.histogram.buckets.each {|b|
      histogram[b.key_as_string] = b.doc_count
    }
    histogram
  end

  def self.identification_counts_by_category( year, options = {} )
    es_params = {
      size: 0,
      filters: [
        { terms: { "created_at_details.year": [year] } },
        { terms: { "own_observation": [false] } },
        { terms: { "observation.quality_grade": ["research", "needs_id"] } },
        { terms: { "current": [true] } }
      ],
      inverse_filters: [
        { exists: { field: "taxon_change_id" } }
      ],
      aggregate: {
        categories: { terms: { field: "category" } }
      }
    }
    if options[:user]
      es_params[:filters] << { terms: { "user.id": [options[:user].id] } }
    end
    if site = options[:site]
      es_params[:filters] << { terms: { "observation.site_id": [site.id] } }
    end
    Identification.elastic_search( es_params ).response.aggregations.categories.buckets.inject({}) do |memo, bucket|
      memo[bucket["key"]] = bucket.doc_count
      memo
    end
  end

  def self.obervation_counts_by_quality_grade( year, options = {} )
    params = { year: year }
    params[:user_id] = options[:user].id if options[:user]
    if site = options[:site]
      params[:site_id] = site.id
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
      params[:site_id] = site.id
    end
    # Observation.elastic_taxon_leaf_counts( Observation.params_to_elastic_query( params ) ).size
    JSON.parse( INatAPIService.get_json( "/observations/species_counts", params, 3, 30 ) )["total_results"].to_i
  end

  def self.iconic_taxa_counts( year, options = {} )
    params = { year: year, verifiable: true }
    params[:user_id] = options[:user].id if options[:user]
    if site = options[:site]
      params[:site_id] = site.id
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
      params[:site_id] = site.id
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
        { "cached_votes_total": "desc" },
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
      
    JSON.
        parse( INatAPIService.get_json( "/observations", api_params, 3, 30 ) )["results"].
        sort_by{|o| [0 - o["cached_votes_total"].to_i, 0 - o["comments_count"].to_i] }.
        each_with_index.map do |o,i|
      if i < 10
        o.select{|k,v| %w(id taxon community_taxon user photos comments_count cached_votes_total).include?( k ) }
      elsif !o["photos"].blank?
        {
          "id": o["id"],
          "photos": [o["photos"][0].select{|k,v| %w(url original_dimensions).include?( k ) }]
        }
      end
    end.compact
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
      s = ( site || Site.default )
      s.site_name_short.blank? ? s.name : s.site_name_short
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

end
