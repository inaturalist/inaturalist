require 'yaml'
require 'active_support/core_ext/hash'
require 'active_support/hash_with_indifferent_access'

class InatConfig

  def initialize(config_file)
    # Path to default config file
    default_config_file = config_file + '.example'

    # Config yaml
    config_yaml = YAML.load_file(config_file)[Rails.env]

    @config = config_yaml
    
    # Load and merge default config if it exists
    if File.exists? default_config_file
      default_config_yaml = YAML.load_file(default_config_file)[Rails.env]
      @config = default_config_yaml.deep_merge(config_yaml)
    end
    
    @config = HashWithIndifferentAccess.new(@config)
  end

  def get(*keys)
    value = @config
    begin
      keys.each do |key|
        value = value.fetch(key)
      end
    rescue KeyError => error
      Rails.logger.error "Missing config values: #{keys.join(':')}"
      value = nil
    end
    value
  end

  def to_hash
    @config
  end
end
