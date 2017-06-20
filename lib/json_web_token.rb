require "jwt"

class JsonWebToken
  def self.encode(payload, expiration = 24.hours.from_now)
    payload = payload.dup
    payload[:exp] = expiration.to_i
    JWT.encode(payload, CONFIG.jwt_secret || "secret", "HS512")
  end

  def self.decode(token)
    JWT.decode(token, CONFIG.jwt_secret || "secret").first
  end

  def self.applicationToken(expiration = 5.minutes.from_now)
    payload = { application: "rails" }
    payload[:exp] = expiration.to_i
    JWT.encode(payload, CONFIG.jwt_application_secret || "secret", "HS512")
  end
end
