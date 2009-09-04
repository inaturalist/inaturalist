configuration_bindings = YAML.load(File.open("#{RAILS_ROOT}/config/config.yml"))
if configuration_bindings['base']['hoptoad']
  HoptoadNotifier.configure do |config|
    config.api_key = configuration_bindings['base']['hoptoad']['api_key']
  end
end
