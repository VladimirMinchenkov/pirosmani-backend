FactoryBot.define do
  factory :app_setting do
    sequence(:key) { |n| "setting_#{n}" }
    value { "default_value" }
  end
end
