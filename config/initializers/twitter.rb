if CONFIG.twitter
  Twitter.configure do |config|
    config.consumer_key = CONFIG.twitter.key
    config.consumer_secret = CONFIG.twitter.secret
  end
end
