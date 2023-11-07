class YearStatisticLocalizedShareableImage < ApplicationRecord
  belongs_to :year_statistic

  validates_presence_of :year_statistic
  validates_presence_of :locale

  if CONFIG.usingS3
    has_attached_file :shareable_image,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "year_statistic_localized_shareable_images/:id-:locale.:content_type_extension",
      url: ":s3_alias_url"
    invalidate_cloudfront_caches :shareable_image, "year_statistic_localized_shareable_images/:id-*"
  else
    has_attached_file :shareable_image,
      path: ":rails_root/public/attachments/:class/:id-:locale.:content_type_extension",
      url: "/attachments/:class/:id-:locale.:content_type_extension"
  end

  validates_attachment_content_type :shareable_image,
    content_type: [/jpe?g/i, /png/i, /gif/i, /octet-stream/],
    message: "must be JPG, PNG, or GIF"

  ASSET_CACHE_TIME = 10.minutes

  def generate( options = {} )
    debug = options.delete( :debug )
    if debug
      puts "[#{Time.now}] generate_shareable_image_no_obs, options: #{options}"
    end
    return if locale.blank? || !I18N_SUPPORTED_LOCALES.include?( locale )

    work_path = File.join( Dir.tmpdir, "year-stat-shareable-#{year_statistic.id}-#{locale}-#{Time.now.to_i}" )
    FileUtils.mkdir_p( work_path, mode: 0o755 )

    # generate the base image with background and site wordmark. This can be cached for
    # ASSET_CACHE_TIME since it will be used in many different shreable images
    background_with_wordmark_path = generate_background_with_wordmark( work_path )

    # prepate the text elements
    text = prepare_text
    using_non_latin_chars = text.any?{ |k,v| v.to_s.non_latin_chars? }
    light_font_path, medium_font_path, semibold_font_path = font_paths( using_non_latin_chars )

    # populate an array of extra elements to overlay on the base image
    composites = []

    # add the title, e.g. Year In Review 2023
    composites << title_composite( light_font_path, text[:title] )

    # add the user icon or site logo
    icon_or_logo_path = generate_icon_or_logo( work_path )
    composites << icon_composite( icon_or_logo_path )

    # add the user's username for user year statistics
    unless text[:owner].blank?
      composites << owner_composite( medium_font_path, text[:owner] )
    end

    # add the numbers and labels for the counts
    [
      [text[:obs_count_txt], text[:obs_label_txt]],
      [text[:species_count_txt], text[:species_label_txt]],
      [text[:identifications_count_txt], text[:identifications_label_txt]]
    ].each_with_index do | texts, idx |
      count_txt, label_txt = texts
      y = 80 + ( idx * 145 )
      text_width = 312 # this provides a bit of margin (332 would go to the right edge )
      composites << label_and_count_composite( label_txt, count_txt, y, text_width, semibold_font_path, medium_font_path )
    end

    # combine all composites with the base image into the final shareable image
    final_path = File.join( work_path, "final.jpg" )
    self.class.run_cmd <<~BASH
      convert #{background_with_wordmark_path} \
        #{composites.map( &:strip ).join( " \\\n" )} \
        #{final_path}
    BASH

    puts "final_path: #{final_path}" if debug
    self.shareable_image = File.open( final_path )
    save!
    FileUtils.rm( final_path )
    FileUtils.rm( icon_or_logo_path )
    Dir.delete( work_path )
  end

  def left_vertical_offset
    year_statistic.user ? 0 : 30
  end

  def label_method
    ( Rails.env.production? && locale.to_s =~ /^(il|he|ar|kn|mr|sat|th)/ ) ? "pango" : "label"
  end

  def generate_icon_or_logo( work_path )
    # Get the icon
    icon_or_logo_url = if year_statistic.user
      ApplicationController.helpers.image_url( year_statistic.user.icon.url( :large ) ).to_s.gsub( %r{([^:])//}, "\\1/" )
    elsif year_statistic.site
      ApplicationController.helpers.image_url( year_statistic.site.logo_square.url ).to_s.gsub( %r{([^:])//}, "\\1/" )
    elsif Site.default
      ApplicationController.helpers.image_url( Site.default.logo_square.url ).to_s.gsub( %r{([^:])//}, "\\1/" )
    else
      ApplicationController.helpers.image_url( "bird.png" ).to_s.gsub( %r{([^:])//}, "\\1/" )
    end
    icon_or_logo_url = icon_or_logo_url.sub( "staticdev", "static" ) # basically just for testing
    original_path = self.class.cache_asset( icon_or_logo_url )

    # Resize icon to a 500x500 square
    square_path = File.join( work_path, "square_icon_or_logo.png" )
    resize_cmd = if year_statistic.user
      <<~BASH
        convert #{original_path} \
          -fill transparent \
          -resize "500x500^" \
          -gravity Center \
          -extent 500x500 \
          #{square_path}
      BASH
    else
      <<~BASH
        convert #{original_path} \
          -fill transparent \
          -resize 500x500 \
          -gravity Center \
          -extent 500x500 \
          #{square_path}
      BASH
    end
    self.class.run_cmd resize_cmd

    path = File.join( work_path, "final_icon_or_logo.png" )
    if year_statistic.user
      # Apply circle mask
      self.class.run_cmd <<~BASH
        convert #{square_path} #{self.class.generate_circle_mask} \
          -alpha Off -compose CopyOpacity -composite \
          -scale 212x212 \
          #{path}
      BASH
    else
      self.class.run_cmd "convert #{square_path} -resize 212x212 #{path}"
    end
    FileUtils.rm( square_path )
    return path
  end

  def generate_background_with_wordmark( work_path )
    background_path = self.class.generate_background
    # Overlay the icon onto the montage
    wordmark_site = year_statistic.user&.site || year_statistic.site || Site.default
    wordmark_url = ApplicationController.helpers.
      image_url( wordmark_site.logo.url ).to_s.gsub( %r{([^:])//}, "\\1/" ).
      sub( "staticdev", "static" )
    wordmark_path = self.class.cache_asset( wordmark_url )

    background_with_wordmark_hash = Digest::MD5.hexdigest( background_path + wordmark_path )
    path = File.join( Dir.tmpdir, "year-statistic-background-with-wordmark-#{background_with_wordmark_hash}" )
    if self.class.cached_asset_exists_and_unexpired?( path )
      return path
    end

    wordmark_canvas_path = self.class.cache_imagemagick_template(
      "convert -size 500x562 xc:transparent -type TrueColorAlpha"
    )
    wordmark_resized_path = path + "-wordmark-resized.png"
    density = 1024
    begin
      self.class.run_cmd <<~BASH
        convert -resize 384x65 -background none +antialias -density #{density} \
          #{wordmark_path} #{wordmark_resized_path}
      BASH
    rescue RuntimeError => e
      density /= 2
      raise e if density <= 8
      retry
    end
    wordmark_composite_path = path + "-wordmark-composite.png"
    self.class.run_cmd <<~BASH
      convert #{wordmark_canvas_path} \
        #{wordmark_resized_path} \
        -type TrueColorAlpha \
        -gravity north -geometry +0+#{left_vertical_offset + 70} \
        -composite \
        #{wordmark_composite_path}
    BASH
    self.class.run_cmd <<~BASH
      convert #{background_path} #{wordmark_composite_path} \
        -gravity west -composite #{path}
    BASH
    FileUtils.rm( wordmark_canvas_path )
    FileUtils.rm( wordmark_resized_path )
    FileUtils.rm( wordmark_composite_path )
    path
  end

  def icon_composite( icon_or_logo_path )
    <<~BASH
      #{icon_or_logo_path} \
      -gravity northwest \
      -geometry +145+#{left_vertical_offset + 230} \
      -composite
    BASH
  end

  def title_composite( light_font_path, title )
    <<~BASH
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
  end

  def owner_composite( medium_font_path, owner )
    <<~BASH
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
  end

  def label_and_count_composite( label_txt, count_txt, y, text_width, semibold_font_path, medium_font_path )
    # Note that the use of label below will automatically try to choose the
    # best font size to fit the space
    <<~BASH
      \\( \
        -size #{text_width}x55 \
        -background transparent \
        -font #{semibold_font_path} \
        -fill white \
        #{label_method}:"#{count_txt}" \
        -trim \
        -gravity west \
        -extent #{text_width}x55 \
      \\) \
      -gravity northwest \
      -geometry +668+#{y} \
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
      -geometry +668+#{y + ( 148 - 80 )} \
      -composite
    BASH
  end

  def prepare_text
    text = {}
    text[:owner] = if year_statistic.user
      "@#{year_statistic.user.login}"
    else
      ""
    end
    title = I18n.t( :year_in_review, year: year_statistic.year, locale: locale )
    text[:title] = title.mb_chars.upcase
    obs_count = if ( qg_counts = year_statistic.data.dig( "observations", "quality_grade_counts" ) )
      qg_counts["research"].to_i + qg_counts["needs_id"].to_i
    else
      0
    end
    species_count = year_statistic.data.dig( "taxa", "leaf_taxa_count" ).to_i
    identifications_count = (
      ( year_statistic.data.dig( "identifications", "category_counts" ) || {} ).inject( 0 ) do | sum, keyval |
        sum += keyval[1].to_i
        sum
      end
    ).to_i

    obs_translation = I18n.t( "x_observations_html",
      count: ApplicationController.helpers.number_with_delimiter( obs_count, locale: locale ),
      locale: locale )
    text[:obs_count_txt] = obs_translation[%r{<span.*?>(.+)</span>(.+)}, 1].to_s.mb_chars.upcase
    text[:obs_label_txt] = obs_translation[%r{<span.*?>(.+)</span>(.+)}, 2].to_s.strip.mb_chars.upcase
    species_translation = I18n.t( "x_species_html",
      count: ApplicationController.helpers.number_with_delimiter( species_count, locale: locale ),
      locale: locale )
    text[:species_count_txt] = species_translation[%r{<span.*?>(.+)</span>(.+)}, 1].to_s.mb_chars.upcase
    text[:species_label_txt] = species_translation[%r{<span.*?>(.+)</span>(.+)}, 2].to_s.strip.mb_chars.upcase
    identifications_translation = I18n.t( "x_identifications_html",
      count: ApplicationController.helpers.number_with_delimiter( identifications_count, locale: locale ),
      locale: locale )
    text[:identifications_count_txt] = identifications_translation[%r{<span.*?>(.+)</span>(.+)}, 1].to_s.mb_chars.upcase
    text[:identifications_label_txt] = identifications_translation[%r{<span.*?>(.+)</span>(.+)}, 2].to_s.strip.mb_chars.upcase

    if label_method == "pango"
      text[:title] = "<span size='#{1024 * 22}'>#{text[:title]}</span>"
      text[:owner] = "<span size='#{1024 * 20}'>#{text[:owner]}</span>" unless text[:owner].blank?
      text[:obs_count_txt] = "<span size='#{1024 * 24}'>#{text[:obs_count_txt]}</span>"
      text[:obs_label_txt] = "<span size='#{1024 * 20}'>#{text[:obs_label_txt]}</span>"
      text[:species_count_txt] = "<span size='#{1024 * 24}'>#{text[:species_count_txt]}</span>"
      text[:species_label_txt] = "<span size='#{1024 * 20}'>#{text[:species_label_txt]}</span>"
      text[:identifications_count_txt] = "<span size='#{1024 * 24}'>#{text[:identifications_count_txt]}</span>"
      text[:identifications_label_txt] = "<span size='#{1024 * 20}'>#{text[:identifications_label_txt]}</span>"
    end
    text
  end

  def font_paths( using_non_latin_chars )
    if using_non_latin_chars
      if Rails.env.production?
        if locale =~ /^(ja|ko|zh)/
          light_font_path = "Noto-Sans-CJK-HK"
          medium_font_path = "Noto-Sans-CJK-HK"
          semibold_font_path = "Noto-Sans-CJK-HK-Bold"
        else
          light_font_path = "DejaVu-Sans-ExtraLight"
          medium_font_path = "DejaVu-Sans"
          semibold_font_path = "DejaVu-Sans-Bold"
        end
      else
        light_font_path = "Helvetica-Narrow"
        medium_font_path = "Helvetica"
        semibold_font_path = "Helvetica-Bold"
      end
    else
      light_font_path = File.join( Rails.root, "public", "fonts", "Whitney-Light-Pro.otf" )
      medium_font_path = File.join( Rails.root, "public", "fonts", "Whitney-Medium-Pro.otf" )
      semibold_font_path = File.join( Rails.root, "public", "fonts", "Whitney-Semibold-Pro.otf" )
    end
    [light_font_path, medium_font_path, semibold_font_path]
  end

  def self.cached_asset_exists_and_unexpired?( path )
    File.exist?( path ) &&
      ( File.mtime( path ) > ( Time.now - ASSET_CACHE_TIME ) )
  end

  def self.cache_asset( url )
    url_hash = Digest::MD5.hexdigest( url )
    cache_path = File.join( Dir.tmpdir, "year-statistic-cached-asset-#{url_hash}" )
    if cached_asset_exists_and_unexpired?( cache_path )
      return cache_path
    end

    run_cmd "curl -f -s -o #{cache_path} \"#{url}\""
    url_ext = File.extname( URI.parse( url ).path )
    clean_svg_for_imagemagick( cache_path ) if url_ext.downcase == "svg"
    cache_path
  end

  def self.cache_imagemagick_template( cmd )
    cmd_hash = Digest::MD5.hexdigest( cmd )
    cache_path = File.join( Dir.tmpdir, "year-statistic-cached-template-#{cmd_hash}.png" )
    if cached_asset_exists_and_unexpired?( cache_path )
      return cache_path
    end

    run_cmd "#{cmd.strip} #{cache_path}"
    cache_path
  end

  # ImageMagick's SVG parser is... sensitive, so this filters out things it doesn't like
  def self.clean_svg_for_imagemagick( svg_path )
    tmp_path = "#{svg_path}.tmp"
    run_cmd <<~BASH
      cat #{svg_path} | sed 's/id="Path"// > #{tmp_path}
    BASH
    run_cmd "mv #{tmp_path} #{svg_path}"
  end

  def self.generate_background
    background_url = ApplicationController.helpers.image_url( "yir-background.png" ).to_s.
      gsub( %r{([^:])//}, "\\1/" ).
      gsub( "staging.inaturalist", "www.inaturalist" )
    cache_asset( background_url )
  end

  def self.generate_circle_mask
    cache_imagemagick_template <<~BASH
      convert -size 500x500 xc:black -fill white \
        -draw "translate 250,250 circle 0,0 0,250" -alpha off
    BASH
  end

  def self.run_cmd( cmd, options = { timeout: 60 } )
    Timeout.timeout( options.delete( :timeout ) ) do
      system cmd, options.merge( exception: true )
    end
  end
end
