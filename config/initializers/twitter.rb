if INAT_CONFIG["twitter"]
  Twitter.configure do |config|
    config.consumer_key = INAT_CONFIG["twitter"]["key"]
    config.consumer_secret = INAT_CONFIG["twitter"]["secret"]
  end
end
