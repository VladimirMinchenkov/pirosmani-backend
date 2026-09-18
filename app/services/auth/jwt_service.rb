# app/services/auth/jwt_service.rb
module Auth
  class JwtService
    ALGORITHM = "HS256".freeze
    ACCESS_TOKEN_TTL = 15.minutes

    class InvalidToken < StandardError; end

    def self.encode(client_id:, exp: ACCESS_TOKEN_TTL.from_now)
      payload = { client_id: client_id, exp: exp.to_i, iat: Time.current.to_i }
      JWT.encode(payload, secret, ALGORITHM)
    end

    def self.decode(token)
      payload = JWT.decode(token, secret, true, algorithm: ALGORITHM).first
      payload.with_indifferent_access
    rescue JWT::DecodeError, JWT::ExpiredSignature
      raise InvalidToken
    end

    def self.secret
      Rails.application.secret_key_base
    end
  end
end
