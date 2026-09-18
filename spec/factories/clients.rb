FactoryBot.define do
  factory :client do
    sequence(:phone) { |n| "+3752912345#{n.to_s.rjust(2, '0')}" }
    phone_verified_at { Time.current }
    sequence(:name) { |n| "Client #{n}" }
    bonus_points { 0 }
  end
end
