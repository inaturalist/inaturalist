require 'yaml'
require 'active_support/core_ext/hash'
require 'active_support/hash_with_indifferent_access'

class InatConfig

  def initialize(config_file)
    if config_file.is_a? Hash
      @config = config_file
    else
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
    end

    @config = HashWithIndifferentAccess.new(@config)
  end

  def to_hash
    @config
  end

  def method_missing(method_id, *args, &block)
    if @config.key? method_id
      value =  @config.fetch(method_id)
      if value.is_a? Hash
        value = InatConfig.new(value)
      end
      value
    elsif @config.class.method_defined? method_id
      @config.send(method_id, *args, &block)
    else
      nil
    end
  end

  def site
    return unless site_id
    @site ||= Site.find_by_id(site_id)
  end
end
