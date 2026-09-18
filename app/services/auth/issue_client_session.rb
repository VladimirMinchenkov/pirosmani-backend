# app/services/auth/issue_client_session.rb
module Auth
  class IssueClientSession
    REFRESH_TOKEN_TTL = 30.days

    def self.call(client)
      new(client).call
    end

    def initialize(client)
      @client = client
    end

    def call
      access_token = Auth::JwtService.encode(client_id: client.id)
      raw_refresh_token = SecureRandom.urlsafe_base64(48)

      client.refresh_tokens.create!(
        token: RefreshToken.hash_token(raw_refresh_token),
        expires_at: REFRESH_TOKEN_TTL.from_now
      )

      {
        access_token: access_token,
        refresh_token: raw_refresh_token,
        client: client
      }
    end

    private

    attr_reader :client
  end
end
