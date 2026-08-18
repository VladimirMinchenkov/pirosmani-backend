FactoryBot.define do
  factory :cart do
    session_id { SecureRandom.uuid }
    client_id { nil }

    trait :for_client do
      client
      session_id { nil }
    end

    trait :for_session do
      client { nil }
      session_id { SecureRandom.uuid }
    end
  end
end

