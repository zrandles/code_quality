require 'rails_helper'

RSpec.describe MetricSummary, type: :model do
  describe 'associations' do
    it { should belong_to(:app) }
  end

  describe 'validations' do
    it { should validate_presence_of(:scan_type) }
  end

  describe 'scopes' do
    let(:app) { create(:app) }
    let!(:recent_summary) { create(:metric_summary, app: app, scanned_at: 1.day.ago) }
    let!(:old_summary) { create(:metric_summary, app: app, scanned_at: 10.days.ago) }

    describe '.recent' do
      it 'returns summaries from last 7 days' do
        expect(MetricSummary.recent).to include(recent_summary)
        expect(MetricSummary.recent).not_to include(old_summary)
      end
    end

    describe '.by_type' do
      let!(:security_summary) { create(:metric_summary, :security, app: app) }
      let!(:rubocop_summary) { create(:metric_summary, :rubocop, app: app) }

      it 'filters by scan type' do
        expect(MetricSummary.by_type("security")).to include(security_summary)
        expect(MetricSummary.by_type("security")).not_to include(rubocop_summary)
      end
    end
  end

  describe '#status' do
    it 'returns "healthy" when total_issues is zero' do
      summary = build(:metric_summary, total_issues: 0, high_severity: 0, medium_severity: 0)
      expect(summary.status).to eq("healthy")
    end

    it 'returns "critical" when high_severity > 0' do
      summary = build(:metric_summary, total_issues: 5, high_severity: 2, medium_severity: 3)
      expect(summary.status).to eq("critical")
    end

    it 'returns "warning" when medium_severity > 5' do
      summary = build(:metric_summary, total_issues: 6, high_severity: 0, medium_severity: 6)
      expect(summary.status).to eq("warning")
    end

    it 'returns "healthy" when medium_severity <= 5 and high_severity is 0' do
      summary = build(:metric_summary, total_issues: 5, high_severity: 0, medium_severity: 5)
      expect(summary.status).to eq("healthy")
    end
  end

  describe '#status_color' do
    it 'returns "green" for healthy status' do
      summary = build(:metric_summary, :healthy)
      expect(summary.status_color).to eq("green")
    end

    it 'returns "yellow" for warning status' do
      summary = build(:metric_summary, :warning)
      expect(summary.status_color).to eq("yellow")
    end

    it 'returns "red" for critical status' do
      summary = build(:metric_summary, :critical)
      expect(summary.status_color).to eq("red")
    end
  end

  describe 'metadata serialization' do
    it 'serializes metadata as JSON' do
      summary = create(:metric_summary, metadata: { foo: "bar", count: 42 })
      summary.reload

      expect(summary.metadata).to eq({ "foo" => "bar", "count" => 42 })
    end

    it 'handles empty metadata' do
      summary = create(:metric_summary, metadata: {})
      summary.reload

      expect(summary.metadata).to eq({})
    end

    it 'stores overall_coverage in metadata for test_coverage' do
      summary = create(:metric_summary, :test_coverage)
      expect(summary.metadata["overall_coverage"]).to eq(72.5)
    end
  end
end
