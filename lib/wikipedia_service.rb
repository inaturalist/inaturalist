class WikipediaService < MetaService
  def initialize
    super
    @endpoint = 'http://en.wikipedia.org/w/api.php?'
    @method_param = 'action'
    @default_params = { :format => 'xml' }
  end
end