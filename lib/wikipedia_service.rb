class WikipediaService < MetaService
  def initialize(options = {})
    super(options)
    @endpoint = 'http://en.wikipedia.org/w/api.php?'
    @method_param = 'action'
    @default_params = { :format => 'xml' }
  end
end