class WikipediaService < MetaService
  attr_accessor :base_url

  def initialize(options = {})
    super(options)
    locale = options[:locale] || I18n.locale || 'en'
    subdomain = locale.to_s.split('-').first
    self.base_url = "https://#{subdomain}.wikipedia.org"
    @method_param = 'action'
    @api_endpoint = ApiEndpoint.find_or_create_by(
      title: "Wikipedia (#{ subdomain.upcase })",
      documentation_url: "#{ self.base_url }/w/api.php",
      base_url: "#{ self.base_url }/w/api.php?",
      cache_hours: 168)
    @default_params = { :format => 'xml' }
  end

  def url_for_title(title)
    "#{self.base_url}/wiki/#{title}"
  end

  def page_details(title, options = {})
    if parsed = parsed_response(title, options)
      title = parsed.at("parse").attribute("title").value
      pageid = parsed.at("parse").attribute("pageid").value
      summary = summary_from_parsed( parsed )
      {
        id: pageid,
        title: title,
        url: url_for_title( title.tr(" ", "_") ),
        summary: summary
      }
    end
  end

  def summary(title, options = {})
    if parsed = parsed_response(title, options)
      summary_from_parsed(parsed)
    end
  end

  def summary_from_parsed( parsed )
    hxml = Nokogiri::HTML(HTMLEntities.new.decode(parsed.at( "text" ).try( :inner_text )))
    hxml.search('table').remove
    hxml.search("//comment()").remove
    # Remove all elements that aren't displayed
    hxml.search( "//*[contains(@style,'display:none')]/text()" ).remove
    summary = ( hxml.search("//p").detect{|node| !node.inner_html.strip.blank?} || hxml ).inner_html.to_s.strip
    summary = sanitizer.sanitize(summary, :tags => %w(p i em b strong))
    summary.gsub! /\[.*?\]/, ''
    summary
  end

  def parsed_response(title, options = {})
    parsed = parse( options.merge( page: title, redirects: true ))
    parsed.at("text").try(:inner_text) ? parsed : nil
  rescue Timeout::Error => e
    Rails.logger.info "[INFO] Wikipedia API call failed while setting taxon summary: #{e.message}"
    return
  end

  def sanitizer
    @sanitizer ||= Rails::Html::SafeListSanitizer.new
  end

end
