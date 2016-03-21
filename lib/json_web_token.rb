require "jwt"

class JsonWebToken
  def self.encode(payload, expiration = 30.minutes.from_now)
    payload = payload.dup
    payload[:exp] = expiration.to_i
    JWT.encode(payload, CONFIG.jwt_secret || "secret", "HS512")
  end

  def self.decode(token)
    JWT.decode(token, CONFIG.jwt_secret || "secret").first
  end
end
