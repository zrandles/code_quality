require 'rails_helper'

RSpec.describe AppScannerJob, type: :job do
  let(:scanned_app) { create(:scanned_app) }
  let(:job) { described_class.new }

  describe '#perform' do
    before do
      allow(SecurityScanner).to receive(:new).and_return(double(scan: true))
      allow(StaticAnalysisScanner).to receive(:new).and_return(double(scan: true))
      allow(RubocopScanner).to receive(:new).and_return(double(scan: true))
      allow(DriftScanner).to receive(:new).and_return(double(scan: true))
      allow(Rails.logger).to receive(:info)
    end

    it 'runs SecurityScanner' do
      security_scanner = instance_double(SecurityScanner)
      expect(SecurityScanner).to receive(:new).with(scanned_app).and_return(security_scanner)
      expect(security_scanner).to receive(:scan)

      job.perform(scanned_app.id)
    end

    it 'runs StaticAnalysisScanner' do
      static_scanner = instance_double(StaticAnalysisScanner)
      expect(StaticAnalysisScanner).to receive(:new).with(scanned_app).and_return(static_scanner)
      expect(static_scanner).to receive(:scan)

      job.perform(scanned_app.id)
    end

    it 'runs RubocopScanner' do
      rubocop_scanner = instance_double(RubocopScanner)
      expect(RubocopScanner).to receive(:new).with(scanned_app).and_return(rubocop_scanner)
      expect(rubocop_scanner).to receive(:scan)

      job.perform(scanned_app.id)
    end

    it 'runs DriftScanner' do
      drift_scanner = instance_double(DriftScanner)
      expect(DriftScanner).to receive(:new).with(scanned_app).and_return(drift_scanner)
      expect(drift_scanner).to receive(:scan)

      job.perform(scanned_app.id)
    end

    it 'updates app last_scanned_at' do
      job.perform(scanned_app.id)
      scanned_app.reload

      expect(scanned_app.last_scanned_at).to be_within(1.second).of(Time.current)
    end

    it 'logs start of scan' do
      expect(Rails.logger).to receive(:info).with(/Starting quality scan/)
      job.perform(scanned_app.id)
    end

    it 'logs completion of scan' do
      expect(Rails.logger).to receive(:info).with(/Completed quality scan/)
      job.perform(scanned_app.id)
    end

    context 'when app has critical issues' do
      before do
        create_list(:quality_scan, 2, :critical, scanned_app: scanned_app)
      end

      it 'sets status to critical' do
        job.perform(scanned_app.id)
        expect(scanned_app.reload.status).to eq("critical")
      end
    end

    context 'when app has no critical but many medium issues' do
      before do
        create_list(:quality_scan, 6, :medium, scanned_app: scanned_app)
      end

      it 'sets status to warning' do
        job.perform(scanned_app.id)
        expect(scanned_app.reload.status).to eq("warning")
      end
    end

    context 'when app has few issues' do
      before do
        create_list(:quality_scan, 2, :medium, scanned_app: scanned_app)
      end

      it 'sets status to healthy' do
        job.perform(scanned_app.id)
        expect(scanned_app.reload.status).to eq("healthy")
      end
    end

    context 'when app has no issues' do
      it 'sets status to healthy' do
        job.perform(scanned_app.id)
        expect(scanned_app.reload.status).to eq("healthy")
      end
    end
  end

  describe '#determine_status' do
    it 'returns "critical" when critical_count > 0' do
      expect(job.send(:determine_status, 1, 0)).to eq("critical")
      expect(job.send(:determine_status, 5, 10)).to eq("critical")
    end

    it 'returns "warning" when medium_count > 5' do
      expect(job.send(:determine_status, 0, 6)).to eq("warning")
      expect(job.send(:determine_status, 0, 20)).to eq("warning")
    end

    it 'returns "healthy" when counts are low' do
      expect(job.send(:determine_status, 0, 0)).to eq("healthy")
      expect(job.send(:determine_status, 0, 5)).to eq("healthy")
    end
  end
end
