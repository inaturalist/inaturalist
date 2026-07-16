# frozen_string_literal: true

class WikipediaService < MetaService
  attr_accessor :base_url

  # The outcome of the most recent parsed_response, so callers can tell "we
  # reached Wikipedia and there is no article" (:absent) apart from "we couldn't
  # reach Wikipedia" (:unknown — e.g. throttled or timed out). Both otherwise
  # look identical (page_details/summary return nil for each).
  #   :article — a page with article content
  #   :absent  — a valid response with no article content
  #   :unknown — no response at all (throttled/in progress/timed out)
  attr_reader :content_state

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
    hxml.search( "table" ).remove
    hxml.search( "//comment()" ).remove
    # Remove all elements that aren't displayed
    hxml.search( "//*[contains(@style,'display:none')]/text()" ).remove
    summary = ( hxml.search( "//p" ).detect do | node |
      !node.inner_html.strip.blank?
    end || hxml ).inner_html.to_s.strip
    summary = sanitizer.sanitize( summary, tags: %w(p i em b strong) )
    summary.gsub!( /\[.*?\]/, "" )
    summary
  end

  def parsed_response( title, options = {} )
    @content_state = :unknown
    parsed = parse( options.merge( page: title, redirects: true ) )
    # parse can return nil when the request is in progress or was throttled
    return unless parsed

    if parsed.at( "text" ).try( :inner_text )
      @content_state = :article
      parsed
    else
      # We reached Wikipedia and it has no article for this title.
      @content_state = :absent
      nil
    end
  rescue Timeout::Error => e
    Rails.logger.info "[INFO] Wikipedia API call failed while setting taxon summary: #{e.message}"
    @content_state = :unknown
    nil
  end

  def sanitizer
    @sanitizer ||= Rails::Html::SafeListSanitizer.new
  end
end
