class GoogleRecaptcha
  BASE_URL   = "https://www.google.com/".freeze
  VERIFY_URL = "recaptcha/api/siteverify".freeze

  def self.verify_recaptcha(options)
    params = options.dup
    secret = params.delete(:secret)
    return false unless params[:response] && params[:remoteip] && secret
    response = perform_verify_request(params, secret)
    success?(response)
  end

  private

  def self.success?(response)
    JSON.parse(response.body)["success"]
  end

  def self.perform_verify_request(params, secret)
    Faraday.new(BASE_URL).post(VERIFY_URL) do |req|
      req.params = params.merge(secret: secret)
    end
  end

end
