FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password_digest { BCrypt::Password.create("password123") }
    access_token { SecureRandom.hex(32) }
  end
end