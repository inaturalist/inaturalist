# frozen_string_literal: true

class WikipediaService < MetaService
  attr_accessor :base_url

  CACHE_HOURS = 720

  def initialize( options = {} )
    super
    locale = options[:locale] || I18n.locale || "en"
    subdomain = locale.to_s.split( "-" ).first
    self.base_url = "https://#{subdomain}.wikipedia.org"
    @method_param = "action"
    @api_endpoint = ApiEndpoint.find_or_create_by(
      title: "Wikipedia (#{subdomain.upcase})",
      documentation_url: "#{base_url}/w/api.php",
      base_url: "#{base_url}/w/api.php?"
    )
    if @api_endpoint.cache_hours != WikipediaService::CACHE_HOURS
      @api_endpoint.update( cache_hours: WikipediaService::CACHE_HOURS )
    end
    @default_params = {
      format: "xml"
    }
    return unless subdomain.downcase == "zh"

    @default_params[:variant] = locale.downcase
  end

  def url_for_title( title )
    "#{base_url}/#{@default_params[:variant] || 'wiki'}/#{title}"
  end

  def page_details( title, options = {} )
    parsed = parsed_response( title, options )
    return unless parsed

    title = parsed.at( "parse" ).attribute( "title" ).value
    pageid = parsed.at( "parse" ).attribute( "pageid" ).value
    summary = summary_from_parsed( parsed )
    {
      id: pageid,
      title: title,
      url: url_for_title( title.tr( " ", "_" ) ),
      summary: summary
    }
  end

  def summary( title, options = {} )
    parsed = parsed_response( title, options )
    return unless parsed

    summary_from_parsed( parsed )
  end

  def summary_from_parsed( parsed )
    hxml = Nokogiri::HTML( HTMLEntities.new.decode( parsed.at( "text" ).try( :inner_text ) ) )
    %w[
      style link script noscript table
      .hatnote .ambox .mbox .tmbox .ombox .cmbox .fmbox
      .dablink .rellink .navbox .vertical-navbox .metadata
      .noprint .infobox .sidebar .mw-editsection .navbar
      .taxobox .taxobox_v3 table.infobox
    ].each {| selector | hxml.search( selector ).remove }
    hxml.search( "//comment()" ).remove
    # Remove all elements that aren't displayed
    hxml.search( "//*[contains(@style,'display:none')]/text()" ).remove
    summary_node = hxml.search( "//p" ).detect {| node | lead_paragraph?( node ) }
    summary = ( summary_node || hxml ).inner_html.to_s.strip
    summary = sanitizer.sanitize( summary, tags: %w(p i em b strong) )
    summary.gsub! /\[.*?\]/, ""
    summary
  end

  def parsed_response( title, options = {} )
    parsed = parse( options.merge( page: title, redirects: true ) )
    parsed.at( "text" ).try( :inner_text ) ? parsed : nil
  rescue Timeout::Error => e
    Rails.logger.info "[INFO] Wikipedia API call failed while setting taxon summary: #{e.message}"
  end

  def sanitizer
    @sanitizer ||= Rails::Html::SafeListSanitizer.new
  end

  private

  def lead_paragraph?( node )
    classes = node["class"].to_s.split
    return false if classes.intersect?( %w(noexcerpt mw-empty-elt) )

    text = node.text.to_s.squish
    return false if text.blank?
    return false if css_fragment?( text )

    true
  end

  def css_fragment?( text )
    text.match?( /\A[.#][\w-]+/ ) || ( text.include?( "{" ) && text.include?( "}" ) )
  end
end
