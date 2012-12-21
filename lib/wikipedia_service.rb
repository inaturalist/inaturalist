class WikipediaService < MetaService
  def initialize(options = {})
    super(options)
    locale = options[:locale] || I18n.locale || 'en'
    subdomain = locale.to_s.split('-').first
    @endpoint = "http://#{subdomain}.wikipedia.org/w/api.php?"
    @method_param = 'action'
    @default_params = { :format => 'xml' }
  end
end
