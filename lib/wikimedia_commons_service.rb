class WikimediaCommonsService < MetaService
  def initialize(options = {})
    super(options)
    @endpoint = 'https://commons.wikimedia.org/w/api.php?'
    @method_param = 'action'
    @default_params = { :format => 'xml' }
  end
end
