class WikipediaService < MetaService
  def initialize(options = {})
    super(options)
    @locale = options[:locale] || 'en'
    @endpoint = "http://#{@locale}.wikipedia.org/w/api.php?"
    @method_param = 'action'
    @default_params = { :format => 'xml' }
  end
end