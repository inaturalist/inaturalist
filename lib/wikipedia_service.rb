class WikipediaService < MetaService
  attr_accessor :base_url

  def initialize(options = {})
    super(options)
    locale = options[:locale] || I18n.locale || 'en'
    subdomain = locale.to_s.split('-').first
    self.base_url = "http://#{subdomain}.wikipedia.org"
    @method_param = 'action'
    @api_endpoint = ApiEndpoint.find_or_create_by(
      title: "Wikipedia (#{ subdomain.upcase })",
      documentation_url: "#{ self.base_url }/w/api.php",
      base_url: "#{ self.base_url }/w/api.php?",
      cache_hours: 720)
    @default_params = { :format => 'xml' }
  end

  def url_for_title(title)
    "#{self.base_url}/wiki/#{title}"
  end

  def summary(title, options = {})
    summary = query_results = parsed = nil
    parsed = parse(options.merge(page: title, redirects: true)).at('text').try(:inner_text)
    return unless parsed
    hxml = Nokogiri::HTML(HTMLEntities.new.decode(parsed))
    hxml.search('table').remove
    hxml.search('div').remove
    summary = (hxml.at('p') || hxml).inner_html.to_s
    summary = sanitizer.sanitize(summary, :tags => %w(p i em b strong))
    summary.gsub! /\[.*?\]/, ''
    summary
  rescue Timeout::Error => e
    Rails.logger.info "[INFO] Wikipedia API call failed while setting taxon summary: #{e.message}"
    return
  end

  def sanitizer
    @sanitizer ||= HTML::WhiteListSanitizer.new
  end
end
