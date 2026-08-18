FactoryBot.define do
  factory :refresh_token do
    client { nil }
    token { "MyString" }
    expires_at { "2026-08-18 18:15:51" }
    revoked_at { "2026-08-18 18:15:51" }
  end
end
