# initializers may not be loaded yet
require File.join(Rails.root, "config", "initializers", "extensions")

module SiteConfig
  class << self

    def load
      config = all_yaml
      raise "Config is blank" if config.blank?
      if config[Rails.env.to_s].blank?
        raise "Config missing environment `#{ Rails.env }`"
      end
      # create a nested OpenStruct of the site config
      OpenStruct.new_recursive(config[Rails.env.to_s])
    end

    # allow values to be fetches with dynamic methods
    #   e.g. SiteConfig.rest_auth.REST_AUTH_SITE_KEY
    def method_missing(method, *args)
      # load and cache the config
      @site_config ||= SiteConfig.load
      @site_config.send(method, *args)
    end

    private

    def path
      yml_path = File.join(Rails.root, "config", "config.yml")
      if !File.exist?(yml_path) && File.exist?("#{ yml_path }.example")
        # if there is no config.yml, use the example if it exists
        return "#{ yml_path }.example"
      end
      yml_path
    end

    def all_yaml
      # load the entire config.yml into a hash
      YAML.load(File.open(path))
    end

  end
end
