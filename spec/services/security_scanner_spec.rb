require 'rails_helper'

RSpec.describe SecurityScanner do
  let(:app) { create(:app, path: "/tmp/test_app") }
  let(:scanner) { described_class.new(app) }

  describe '#scan' do
    context 'when app directory does not exist' do
      before do
        allow(File).to receive(:directory?).with(app.path).and_return(false)
      end

      it 'does not run brakeman' do
        expect(scanner).not_to receive(:system)
        scanner.scan
      end
    end

    context 'when app directory exists' do
      let(:brakeman_output) do
        {
          "warnings" => [
            {
              "warning_type" => "SQL Injection",
              "message" => "Possible SQL injection",
              "file" => "app/models/user.rb",
              "line" => 42,
              "confidence" => "High"
            },
            {
              "warning_type" => "Mass Assignment",
              "message" => "Unprotected mass assignment",
              "file" => "app/controllers/users_controller.rb",
              "line" => 15,
              "confidence" => "Medium"
            }
          ]
        }
      end

      before do
        allow(File).to receive(:directory?).with(app.path).and_return(true)
        allow(scanner).to receive(:system).and_return(true)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(/brakeman.*\.json/).and_return(true)
        allow(File).to receive(:read).with(/brakeman.*\.json/).and_return(brakeman_output.to_json)
        allow(File).to receive(:delete).and_return(true)
      end

      it 'runs brakeman command' do
        expect(scanner).to receive(:system).with(/brakeman/)
        scanner.scan
      end

      it 'parses brakeman results and creates quality scans' do
        scanner.scan

        scans = app.quality_scans.where(scan_type: "security")
        expect(scans.count).to eq(2)
      end

      it 'maps confidence to severity correctly' do
        scanner.scan

        high_confidence_scan = app.quality_scans.find_by(severity: "critical")
        expect(high_confidence_scan.message).to include("SQL Injection")

        medium_confidence_scan = app.quality_scans.find_by(severity: "high")
        expect(medium_confidence_scan.message).to include("Mass Assignment")
      end

      it 'stores file path and line number' do
        scanner.scan

        scan = app.quality_scans.first
        expect(scan.file_path).to eq("app/models/user.rb")
        expect(scan.line_number).to eq(42)
      end

      it 'creates metric summary' do
        scanner.scan

        summary = app.metric_summaries.find_by(scan_type: "security")
        expect(summary).to be_present
        expect(summary.total_issues).to eq(2)
        expect(summary.high_severity).to eq(2) # Both critical and high map to high_severity
      end

      it 'deletes temporary output file' do
        expect(File).to receive(:delete).with(/brakeman.*\.json/)
        scanner.scan
      end

      it 'clears old security scans before creating new ones' do
        create(:quality_scan, :security, app: app, message: "Old scan")

        scanner.scan

        expect(app.quality_scans.where(scan_type: "security").pluck(:message)).not_to include("Old scan")
      end
    end

    context 'when brakeman output file does not exist' do
      before do
        allow(File).to receive(:directory?).with(app.path).and_return(true)
        allow(scanner).to receive(:system).and_return(true)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(/brakeman.*\.json/).and_return(false)
      end

      it 'does not create any scans' do
        scanner.scan
        expect(app.quality_scans.count).to eq(0)
      end
    end

    context 'when brakeman fails' do
      before do
        allow(File).to receive(:directory?).with(app.path).and_return(true)
        allow(scanner).to receive(:system).and_return(true)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(/brakeman.*\.json/).and_return(true)
        allow(File).to receive(:read).and_raise(JSON::ParserError)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and continues' do
        expect(Rails.logger).to receive(:error).with(/Brakeman scan failed/)
        scanner.scan
      end
    end
  end

  describe '#severity_for_confidence' do
    it 'maps "high" confidence to "critical" severity' do
      expect(scanner.send(:severity_for_confidence, "High")).to eq("critical")
    end

    it 'maps "medium" confidence to "high" severity' do
      expect(scanner.send(:severity_for_confidence, "Medium")).to eq("high")
    end

    it 'maps "weak" confidence to "medium" severity' do
      expect(scanner.send(:severity_for_confidence, "Weak")).to eq("medium")
    end

    it 'maps unknown confidence to "low" severity' do
      expect(scanner.send(:severity_for_confidence, "Unknown")).to eq("low")
      expect(scanner.send(:severity_for_confidence, nil)).to eq("low")
    end
  end
end
