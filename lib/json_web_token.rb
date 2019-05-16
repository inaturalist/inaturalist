require "jwt"

class JsonWebToken
  def self.encode(payload, expiration = 24.hours.from_now)
    payload = payload.dup
    payload[:exp] = expiration.to_i
    JWT.encode(payload, CONFIG.jwt_secret || "secret", "HS512")
  end

  def self.decode(token)
    JWT.decode(token, CONFIG.jwt_secret || "secret", true, { algorithm: "HS512" }).first
  end

  def self.applicationToken(expiration = 5.minutes.from_now)
    payload = { application: "rails" }
    payload[:exp] = expiration.to_i
    JWT.encode(payload, CONFIG.jwt_application_secret || "application_secret", "HS512")
  end

  def self.decodeApplication( token )
    JWT.decode( token, CONFIG.jwt_application_secret || "application_secret", true, { algorithm: "HS512" } ).first
  end
end
