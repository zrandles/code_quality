require 'rails_helper'

RSpec.describe ScanRun, type: :model do
  describe 'associations' do
    it { should belong_to(:app) }
  end

  describe 'scopes' do
    let(:app) { create(:app) }

    describe '.recent' do
      it 'returns last 10 scan runs ordered by started_at desc' do
        15.times { create(:scan_run, app: app, started_at: rand(1..30).days.ago) }

        recent_runs = ScanRun.recent
        expect(recent_runs.count).to eq(10)

        # Verify ordering
        expect(recent_runs.first.started_at).to be >= recent_runs.last.started_at
      end
    end

    describe '.completed' do
      let!(:completed_run) { create(:scan_run, :completed, app: app) }
      let!(:in_progress_run) { create(:scan_run, :in_progress, app: app) }

      it 'returns only completed scan runs' do
        expect(ScanRun.completed).to include(completed_run)
        expect(ScanRun.completed).not_to include(in_progress_run)
      end
    end
  end

  describe '#duration' do
    it 'calculates duration for completed runs' do
      run = create(:scan_run, started_at: 10.minutes.ago, completed_at: 5.minutes.ago)
      expect(run.duration).to be_within(1).of(5.minutes)
    end

    it 'returns nil when completed_at is nil' do
      run = create(:scan_run, :in_progress)
      expect(run.duration).to be_nil
    end

    it 'returns nil when started_at is nil' do
      run = build(:scan_run, started_at: nil, completed_at: Time.current)
      expect(run.duration).to be_nil
    end

    it 'returns nil when both timestamps are nil' do
      run = build(:scan_run, started_at: nil, completed_at: nil)
      expect(run.duration).to be_nil
    end
  end

  describe 'scan_types serialization' do
    it 'serializes scan_types as JSON array' do
      run = create(:scan_run, scan_types: ["security", "rubocop"])
      run.reload

      expect(run.scan_types).to eq(["security", "rubocop"])
    end

    it 'handles empty scan_types array' do
      run = create(:scan_run, scan_types: [])
      run.reload

      expect(run.scan_types).to eq([])
    end

    it 'stores all scanner types for full scan' do
      run = create(:scan_run, :all_scanners)
      expect(run.scan_types).to include(
        "security",
        "static_analysis",
        "rubocop",
        "test_coverage",
        "drift"
      )
    end
  end
end
