FactoryBot.define do
  factory :addon_group do
    sequence(:name) { |n| "Addon Group #{n}" }
    min_selection { 0 }
    max_selection { 3 }
    required { false }

    trait :required do
      required { true }
      min_selection { 1 }
    end

    trait :with_addons do
      transient do
        addons_count { 3 }
      end

      after(:create) do |group, evaluator|
        create_list(:addon, evaluator.addons_count, addon_group: group)
      end
    end
  end
end