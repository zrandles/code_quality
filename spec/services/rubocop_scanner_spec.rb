require 'rails_helper'

RSpec.describe RubocopScanner do
  let(:scanned_app) { create(:scanned_app, path: "/tmp/test_app") }
  let(:scanner) { described_class.new(scanned_app) }

  describe '#scan' do
    context 'when app directory does not exist' do
      before do
        allow(File).to receive(:directory?).with(scanned_app.path).and_return(false)
      end

      it 'does not run rubocop' do
        expect(scanner).not_to receive(:system)
        scanner.scan
      end
    end

    context 'when app directory exists' do
      let(:output_file) { Rails.root.join("tmp", "rubocop_#{scanned_app.name}.json") }
      let(:rubocop_output) do
        {
          "files" => [
            {
              "path" => "app/models/user.rb",
              "offenses" => [
                {
                  "severity" => "error",
                  "cop_name" => "Lint/Debugger",
                  "message" => "Remove debugger entry point",
                  "location" => { "start_line" => 25 }
                },
                {
                  "severity" => "warning",
                  "cop_name" => "Lint/UnusedMethodArgument",
                  "message" => "Unused method argument - user",
                  "location" => { "start_line" => 42 }
                }
              ]
            }
          ]
        }
      end

      before do
        allow(File).to receive(:directory?).with(scanned_app.path).and_return(true)
        allow(scanner).to receive(:system).and_return(true)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(output_file).and_return(true)
        allow(File).to receive(:read).with(output_file).and_return(rubocop_output.to_json)
        allow(File).to receive(:delete).with(output_file).and_return(true)
      end

      it 'runs rubocop with only high-value cops' do
        expect(scanner).to receive(:system).with(/--only/)
        scanner.scan
      end

      it 'parses rubocop output and creates quality scans' do
        scanner.scan

        scans = scanned_app.quality_scans.where(scan_type: "rubocop")
        expect(scans.count).to eq(2)
      end

      it 'maps severity correctly' do
        scanner.scan

        error_scan = scanned_app.quality_scans.find { |s| s.message.include?("Debugger") }
        warning_scan = scanned_app.quality_scans.find { |s| s.message.include?("UnusedMethodArgument") }

        expect(error_scan.severity).to eq("high")
        expect(warning_scan.severity).to eq("medium")
      end

      it 'stores cop name and message' do
        scanner.scan

        scan = scanned_app.quality_scans.first
        expect(scan.message).to include("Lint/")
        expect(scan.message).to include(":")
      end

      it 'stores file path and line number' do
        scanner.scan

        scan = scanned_app.quality_scans.first
        expect(scan.file_path).to eq("app/models/user.rb")
        expect(scan.line_number).to eq(25)
      end

      it 'creates metric summary' do
        scanner.scan

        summary = scanned_app.metric_summaries.find_by(scan_type: "rubocop")
        expect(summary).to be_present
        expect(summary.total_issues).to eq(2)
        expect(summary.high_severity).to eq(1)
        expect(summary.medium_severity).to eq(1)
      end

      it 'deletes temporary output file' do
        expect(File).to receive(:delete).with(output_file)
        scanner.scan
      end

      it 'clears old rubocop scans before creating new ones' do
        create(:quality_scan, :rubocop, scanned_app: scanned_app, message: "Old scan")

        scanner.scan

        expect(scanned_app.quality_scans.where(scan_type: "rubocop").pluck(:message)).not_to include("Old scan")
      end
    end

    context 'when rubocop output file does not exist' do
      before do
        allow(File).to receive(:directory?).with(scanned_app.path).and_return(true)
        allow(scanner).to receive(:system).and_return(true)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(/rubocop.*\.json/).and_return(false)
      end

      it 'does not create any scans' do
        scanner.scan
        expect(scanned_app.quality_scans.count).to eq(0)
      end
    end

    context 'when rubocop fails' do
      let(:output_file) { Rails.root.join("tmp", "rubocop_#{scanned_app.name}.json") }

      before do
        allow(File).to receive(:directory?).with(scanned_app.path).and_return(true)
        allow(scanner).to receive(:system).and_return(true)
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(output_file).and_return(true)
        allow(File).to receive(:read).with(output_file).and_raise(JSON::ParserError)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error and continues' do
        expect(Rails.logger).to receive(:error).with(/RuboCop scan failed/)
        scanner.scan
      end
    end
  end

  describe '#rubocop_severity' do
    it 'maps "error" to "high"' do
      expect(scanner.send(:rubocop_severity, "error")).to eq("high")
    end

    it 'maps "fatal" to "high"' do
      expect(scanner.send(:rubocop_severity, "fatal")).to eq("high")
    end

    it 'maps "warning" to "medium"' do
      expect(scanner.send(:rubocop_severity, "warning")).to eq("medium")
    end

    it 'maps unknown severity to "low"' do
      expect(scanner.send(:rubocop_severity, "convention")).to eq("low")
      expect(scanner.send(:rubocop_severity, nil)).to eq("low")
    end
  end

  describe 'HIGH_VALUE_COPS constant' do
    it 'includes important security cops' do
      expect(RubocopScanner::HIGH_VALUE_COPS).to include(
        "Security/Eval",
        "Security/Open",
        "Security/MarshalLoad"
      )
    end

    it 'includes important lint cops' do
      expect(RubocopScanner::HIGH_VALUE_COPS).to include(
        "Lint/Debugger",
        "Lint/UnusedMethodArgument",
        "Lint/UselessAssignment"
      )
    end

    it 'includes important Rails cops' do
      expect(RubocopScanner::HIGH_VALUE_COPS).to include(
        "Rails/OutputSafety",
        "Rails/FindEach",
        "Rails/HasManyOrHasOneDependent"
      )
    end
  end
end
