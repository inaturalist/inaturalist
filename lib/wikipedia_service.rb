class WikipediaService < MetaService
  attr_accessor :base_url
  def initialize(options = {})
    super(options)
    locale = options[:locale] || I18n.locale || 'en'
    subdomain = locale.to_s.split('-').first
    self.base_url = "http://#{subdomain}.wikipedia.org"
    @endpoint = "#{self.base_url}/w/api.php?"
    @method_param = 'action'
    @default_params = { :format => 'xml' }
  end

  def url_for_title(title)
    "#{self.base_url}/wiki/#{title}"
  end

  def summary(title)
    summary = query_results = parsed = nil
    parsed = parse(:page => title, :redirects => true).at('text').try(:inner_text)
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
