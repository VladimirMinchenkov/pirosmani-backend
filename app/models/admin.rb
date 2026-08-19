class Admin < ApplicationRecord
  has_secure_password
  validates :email, presence: true, uniqueness: true

  before_create :generate_access_token

  private

  def generate_access_token
    self.access_token = SecureRandom.urlsafe_base64(32)
  end
end