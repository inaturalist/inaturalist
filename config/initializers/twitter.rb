puts(CONFIG.inspect)
puts(CONFIG.twitter.inspect)
puts(CONFIG.twitter.key.inspect)
puts(CONFIG.twitter.secret.inspect)
if CONFIG.twitter
  Twitter.configure do |config|
    config.consumer_key = CONFIG.twitter.key
    config.consumer_secret = CONFIG.twitter.secret
  end
end
