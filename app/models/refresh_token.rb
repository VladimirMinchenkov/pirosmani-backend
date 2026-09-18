# app/models/refresh_token.rb
class RefreshToken < ApplicationRecord
  belongs_to :client

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.hash_token(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def active?
    !revoked? && !expired?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
