require 'rails_helper'

RSpec.describe ScannedApp, type: :model do
  describe 'validations' do
    subject { build(:scanned_app) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:path) }
    it { should validate_uniqueness_of(:name) }
  end

  describe 'associations' do
    it { should have_many(:quality_scans).dependent(:destroy) }
    it { should have_many(:metric_summaries).dependent(:destroy) }
    it { should have_many(:scan_runs).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:recently_scanned_app) { create(:scanned_app, last_scanned_at: 1.hour.ago) }
    let!(:needs_scan_app) { create(:scanned_app, last_scanned_at: 2.days.ago) }
    let!(:never_scanned_app) { create(:scanned_app, last_scanned_at: nil) }

    describe '.recently_scanned' do
      it 'returns apps scanned within last 24 hours' do
        expect(ScannedApp.recently_scanned).to include(recently_scanned_app)
        expect(ScannedApp.recently_scanned).not_to include(needs_scan_app)
        expect(ScannedApp.recently_scanned).not_to include(never_scanned_app)
      end
    end

    describe '.needs_scan' do
      it 'returns apps not scanned in last 24 hours' do
        expect(ScannedApp.needs_scan).to include(needs_scan_app)
        expect(ScannedApp.needs_scan).to include(never_scanned_app)
        expect(ScannedApp.needs_scan).not_to include(recently_scanned_app)
      end
    end
  end

  describe '#scan_status_color' do
    it 'returns green for healthy status' do
      app = build(:scanned_app, status: "healthy")
      expect(app.scan_status_color).to eq("green")
    end

    it 'returns yellow for warning status' do
      app = build(:scanned_app, status: "warning")
      expect(app.scan_status_color).to eq("yellow")
    end

    it 'returns red for critical status' do
      app = build(:scanned_app, status: "critical")
      expect(app.scan_status_color).to eq("red")
    end

    it 'returns gray for unknown status' do
      app = build(:scanned_app, status: "unknown")
      expect(app.scan_status_color).to eq("gray")
    end

    it 'returns gray for nil status' do
      app = build(:scanned_app, status: nil)
      expect(app.scan_status_color).to eq("gray")
    end
  end

  describe '#latest_summaries' do
    let(:scanned_app) { create(:scanned_app) }

    it 'returns latest summary for each scan type' do
      old_security = create(:metric_summary, scanned_app: scanned_app, scan_type: "security", scanned_at: 2.days.ago)
      new_security = create(:metric_summary, scanned_app: scanned_app, scan_type: "security", scanned_at: 1.hour.ago)
      rubocop = create(:metric_summary, scanned_app: scanned_app, scan_type: "rubocop", scanned_at: 1.hour.ago)

      latest = scanned_app.latest_summaries

      expect(latest["security"]).to eq(new_security)
      expect(latest["rubocop"]).to eq(rubocop)
      expect(latest.keys).to contain_exactly("security", "rubocop")
    end

    it 'returns empty hash when no summaries exist' do
      expect(scanned_app.latest_summaries).to eq({})
    end

    it 'groups by scan type correctly' do
      create(:metric_summary, scanned_app: scanned_app, scan_type: "security")
      create(:metric_summary, scanned_app: scanned_app, scan_type: "static_analysis")
      create(:metric_summary, scanned_app: scanned_app, scan_type: "rubocop")

      latest = scanned_app.latest_summaries

      expect(latest.keys).to contain_exactly("security", "static_analysis", "rubocop")
    end
  end
end
