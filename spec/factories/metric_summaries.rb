FactoryBot.define do
  factory :metric_summary do
    association :app
    scan_type { "security" }
    total_issues { 10 }
    high_severity { 2 }
    medium_severity { 5 }
    low_severity { 3 }
    average_score { nil }
    scanned_at { Time.current }
    metadata { {} }

    trait :security do
      scan_type { "security" }
      total_issues { 5 }
      high_severity { 2 }
      medium_severity { 2 }
      low_severity { 1 }
    end

    trait :static_analysis do
      scan_type { "static_analysis" }
      total_issues { 15 }
      high_severity { 3 }
      medium_severity { 8 }
      low_severity { 4 }
      average_score { 18.5 }
    end

    trait :rubocop do
      scan_type { "rubocop" }
      total_issues { 8 }
      high_severity { 1 }
      medium_severity { 4 }
      low_severity { 3 }
    end

    trait :test_coverage do
      scan_type { "test_coverage" }
      total_issues { 3 }
      high_severity { 1 }
      medium_severity { 2 }
      low_severity { 0 }
      average_score { 72.5 }
      metadata { { overall_coverage: 72.5 } }
    end

    trait :drift do
      scan_type { "drift" }
      total_issues { 4 }
      high_severity { 2 }
      medium_severity { 2 }
      low_severity { 0 }
    end

    trait :healthy do
      total_issues { 0 }
      high_severity { 0 }
      medium_severity { 0 }
      low_severity { 0 }
    end

    trait :warning do
      total_issues { 8 }
      high_severity { 0 }
      medium_severity { 6 }
      low_severity { 2 }
    end

    trait :critical do
      total_issues { 12 }
      high_severity { 5 }
      medium_severity { 4 }
      low_severity { 3 }
    end
  end
end
