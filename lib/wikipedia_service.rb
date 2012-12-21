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
end
