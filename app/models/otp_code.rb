# app/models/otp_code.rb
class OtpCode < ApplicationRecord
  OTP_LENGTH = 6
  OTP_TTL = Rails.env.development? ? 30.minutes : 5.minutes

  scope :active, -> { where(verified_at: nil).where("expires_at > ?", Time.current) }

  validates :phone, presence: true
  validates :code, presence: true, length: { is: OTP_LENGTH }

  def self.generate_for(phone)
    code = format("%0#{OTP_LENGTH}d", rand(10.pow(OTP_LENGTH)))
    create!(phone: phone, code: code, expires_at: OTP_TTL.from_now)
  end

  def verify!(candidate)
    return false if expired? || verified?
    return false unless active?
    return false unless candidate == code

    update!(verified_at: Time.current)
    true
  end

  def expired?
    expires_at < Time.current
  end

  def verified?
    verified_at.present?
  end

  def active?
    !expired? && !verified?
  end
end