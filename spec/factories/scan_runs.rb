FactoryBot.define do
  factory :scan_run do
    association :app
    scan_types { ["security", "static_analysis", "rubocop"] }
    started_at { Time.current }
    completed_at { nil }

    trait :completed do
      started_at { 1.hour.ago }
      completed_at { 30.minutes.ago }
    end

    trait :in_progress do
      started_at { 5.minutes.ago }
      completed_at { nil }
    end

    trait :quick do
      started_at { 2.minutes.ago }
      completed_at { 1.minute.ago }
    end

    trait :slow do
      started_at { 30.minutes.ago }
      completed_at { 5.minutes.ago }
    end

    trait :all_scanners do
      scan_types { ["security", "static_analysis", "rubocop", "test_coverage", "drift"] }
    end

    trait :security_only do
      scan_types { ["security"] }
    end
  end
end
