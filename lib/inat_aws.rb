class INatAWS

  def self.config
    YAML.load_file(File.join(Rails.root, "config", "s3.yml"))
  end

  def self.cloudfront_invalidate(path)
    config = INatAWS.config
    return unless Rails.env.production? &&
      path &&
      config["access_key_id"] &&
      config["secret_access_key"] &&
      config["cloudfront_distribution"]
    # AWS expects paths to begin with /
    if path[0] != "/"
      path = "/" + path
    end
    cf = AWS::CloudFront.new(
      access_key_id: config["access_key_id"],
      secret_access_key: config["secret_access_key"])
    cf.client.create_invalidation({
      distribution_id: config["cloudfront_distribution"],
      invalidation_batch: {
        paths: {
          quantity: 1,
          items: [path],
        },
        caller_reference: SecureRandom.uuid
      }
    })
  end
end
