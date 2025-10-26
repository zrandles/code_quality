FactoryBot.define do
  factory :quality_scan do
    association :scanned_app
    scan_type { "security" }
    severity { "medium" }
    message { "Sample quality issue detected" }
    file_path { "app/models/example.rb" }
    line_number { 42 }
    metric_value { nil }
    scanned_at { Time.current }

    trait :security do
      scan_type { "security" }
      severity { "high" }
      message { "SQL Injection: Possible SQL injection vulnerability" }
    end

    trait :static_analysis do
      scan_type { "static_analysis" }
      severity { "medium" }
      message { "FeatureEnvy: Example has feature envy" }
      metric_value { 15.5 }
    end

    trait :rubocop do
      scan_type { "rubocop" }
      severity { "low" }
      message { "Lint/UselessAssignment: Useless assignment to variable" }
    end

    trait :test_coverage do
      scan_type { "test_coverage" }
      severity { "medium" }
      message { "Low test coverage: 45.2%" }
      metric_value { 45.2 }
    end

    trait :drift do
      scan_type { "drift" }
      severity { "critical" }
      message { "Path-based routing not configured" }
      file_path { "config/environments/production.rb" }
    end

    trait :critical do
      severity { "critical" }
    end

    trait :high do
      severity { "high" }
    end

    trait :medium do
      severity { "medium" }
    end

    trait :low do
      severity { "low" }
    end

    trait :info do
      severity { "info" }
      message { "Overall test coverage: 85.3%" }
      metric_value { 85.3 }
    end
  end
end
