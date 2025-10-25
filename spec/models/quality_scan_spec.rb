require 'rails_helper'

RSpec.describe QualityScan, type: :model do
  describe 'associations' do
    it { should belong_to(:app) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:scan_type).in_array(QualityScan::SCAN_TYPES) }

    it 'validates severity inclusion when present' do
      scan = build(:quality_scan, severity: "invalid")
      expect(scan).not_to be_valid
      expect(scan.errors[:severity]).to be_present
    end

    it 'allows nil severity' do
      scan = build(:quality_scan, severity: nil)
      expect(scan).to be_valid
    end

    it 'allows valid severities' do
      QualityScan::SEVERITIES.each do |severity|
        scan = build(:quality_scan, severity: severity)
        expect(scan).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:app) { create(:app) }
    let!(:recent_scan) { create(:quality_scan, app: app, scanned_at: 1.day.ago) }
    let!(:old_scan) { create(:quality_scan, app: app, scanned_at: 10.days.ago) }

    describe '.recent' do
      it 'returns scans from last 7 days' do
        expect(QualityScan.recent).to include(recent_scan)
        expect(QualityScan.recent).not_to include(old_scan)
      end
    end

    describe '.by_type' do
      let!(:security_scan) { create(:quality_scan, :security, app: app) }
      let!(:rubocop_scan) { create(:quality_scan, :rubocop, app: app) }

      it 'filters by scan type' do
        expect(QualityScan.by_type("security")).to include(security_scan)
        expect(QualityScan.by_type("security")).not_to include(rubocop_scan)
      end
    end

    describe '.by_severity' do
      let!(:critical_scan) { create(:quality_scan, :critical, app: app) }
      let!(:low_scan) { create(:quality_scan, :low, app: app) }

      it 'filters by severity' do
        expect(QualityScan.by_severity("critical")).to include(critical_scan)
        expect(QualityScan.by_severity("critical")).not_to include(low_scan)
      end
    end

    describe '.critical_issues' do
      let!(:critical_scan) { create(:quality_scan, severity: "critical", app: app) }
      let!(:high_scan) { create(:quality_scan, severity: "high", app: app) }
      let!(:medium_scan) { create(:quality_scan, severity: "medium", app: app) }

      it 'returns critical and high severity scans' do
        critical_issues = QualityScan.critical_issues
        expect(critical_issues).to include(critical_scan, high_scan)
        expect(critical_issues).not_to include(medium_scan)
      end
    end
  end

  describe 'constants' do
    it 'defines expected scan types' do
      expect(QualityScan::SCAN_TYPES).to include(
        "security",
        "static_analysis",
        "rubocop",
        "test_coverage",
        "drift"
      )
    end

    it 'defines expected severities' do
      expect(QualityScan::SEVERITIES).to eq(%w[critical high medium low info])
    end
  end
end
