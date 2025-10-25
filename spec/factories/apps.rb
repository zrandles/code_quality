FactoryBot.define do
  factory :app do
    sequence(:name) { |n| "test_app_#{n}" }
    sequence(:path) { |n| "/tmp/test_apps/test_app_#{n}" }
    status { "healthy" }
    last_scanned_at { nil }

    trait :recently_scanned do
      last_scanned_at { 1.hour.ago }
    end

    trait :needs_scan do
      last_scanned_at { 2.days.ago }
    end

    trait :healthy do
      status { "healthy" }
    end

    trait :warning do
      status { "warning" }
    end

    trait :critical do
      status { "critical" }
    end

    trait :with_scans do
      after(:create) do |app|
        create_list(:quality_scan, 3, app: app, scan_type: "security")
        create_list(:quality_scan, 2, app: app, scan_type: "static_analysis")
      end
    end

    trait :with_summaries do
      after(:create) do |app|
        create(:metric_summary, app: app, scan_type: "security")
        create(:metric_summary, app: app, scan_type: "static_analysis")
        create(:metric_summary, app: app, scan_type: "rubocop")
      end
    end
  end
end
