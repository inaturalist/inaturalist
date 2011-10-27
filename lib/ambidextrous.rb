module Ambidextrous
  protected
  def auth_url_for(provider, options = {})
    provider = provider.downcase
    openid_urls = {
      "google" => "https://www.google.com/accounts/o8/id",
      "yahoo" => "https://me.yahoo.com"
    }
    # if provider uses openid, url is of form /auth/open_id?openid_url=...
    # else url is simply /auth/:provider_name
    url = "/auth/"
    if openid_urls.has_key?(provider)
      url += 'open_id'
      options[:openid_url] = openid_urls[provider]
    else
      url += provider
    end
    url += "?" + options.map{|k,v| "#{k}=#{v}"}.join('&') unless options.blank?
    url
  end
end
