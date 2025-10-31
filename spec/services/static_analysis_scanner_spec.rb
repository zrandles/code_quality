require 'rails_helper'

RSpec.describe StaticAnalysisScanner do
  let(:scanned_app) { create(:scanned_app, path: "/tmp/test_app") }
  let(:scanner) { described_class.new(scanned_app) }

  describe '#scan' do
    context 'when app directory does not exist' do
      before do
        allow(File).to receive(:directory?).with(scanned_app.path).and_return(false)
      end

      it 'does not run any scanners' do
        expect(scanner).not_to receive(:system)
        scanner.scan
      end
    end

    context 'when app directory exists' do
      before do
        allow(File).to receive(:directory?).with(scanned_app.path).and_return(true)
      end

      describe 'reek scanning' do
        let(:output_file) { Rails.root.join("tmp", "reek_#{scanned_app.name}.json") }
        let(:reek_output) do
          [
            {
              "source" => "app/models/user.rb",
              "smells" => [
                {
                  "smell_type" => "FeatureEnvy",
                  "message" => "User has feature envy of Account",
                  "lines" => [15, 16, 17]
                }
              ]
            }
          ]
        end

        before do
          allow(scanner).to receive(:system).and_return(true)
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(output_file).and_return(true)
          allow(File).to receive(:read).with(output_file).and_return(reek_output.to_json)
          allow(File).to receive(:delete).with(output_file).and_return(true)
          allow(scanner).to receive(:`).and_return("")
        end

        it 'parses reek output and creates quality scans' do
          scanner.scan

          scans = scanned_app.quality_scans.where(scan_type: "reek")
          reek_scan = scans.find { |s| s.message.include?("FeatureEnvy") }

          expect(reek_scan).to be_present
          expect(reek_scan.severity).to eq("medium")
          expect(reek_scan.file_path).to eq("app/models/user.rb")
          expect(reek_scan.line_number).to eq(15)
        end
      end

      describe 'flog scanning' do
        let(:output_file) { Rails.root.join("tmp", "reek_#{scanned_app.name}.json") }
        let(:flog_output) do
          <<~OUTPUT
            app/models/user.rb: (45.2)
               45.2:  User#complex_method
               12.5:  User#another_method
            app/services/processor.rb: (52.0)
               52.0:  Processor#process
          OUTPUT
        end

        before do
          allow(scanner).to receive(:system).and_return(true)
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(output_file).and_return(false)
          allow(scanner).to receive(:`).and_return(flog_output)
          allow(File).to receive(:delete).and_return(true)
        end

        it 'creates scans for high complexity methods (> 20)' do
          scanner.scan

          scans = scanned_app.quality_scans.where(scan_type: "flog")
          # Should create scans for all methods, including low complexity ones
          expect(scans.count).to eq(3) # 45.2, 52.0, and 12.5

          # But only 2 should have medium or high severity
          high_severity_scans = scans.where(severity: ["medium", "high"])
          expect(high_severity_scans.count).to eq(2)
        end

        it 'sets severity based on complexity threshold' do
          scanner.scan

          scans = scanned_app.quality_scans.where(scan_type: "flog")
          very_high = scans.find { |s| s.metric_value == 52.0 }
          high = scans.find { |s| s.metric_value == 45.2 }

          expect(very_high.severity).to eq("high") # > 40
          expect(high.severity).to eq("high") # > 40
        end

        it 'creates low complexity methods with low severity' do
          scanner.scan

          scans = scanned_app.quality_scans.where(scan_type: "flog")
          low_complexity = scans.find { |s| s.message.include?("12.5") }

          # Low complexity methods are still recorded, just with low severity
          expect(low_complexity).to be_present
          expect(low_complexity.severity).to eq("low")
        end
      end

      describe 'flay scanning' do
        let(:flay_output) do
          <<~OUTPUT
            Similar code found in :defn (mass = 50)
              app/models/user.rb:25
              app/models/account.rb:42
          OUTPUT
        end

        before do
          allow(scanner).to receive(:system).and_return(true)
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/reek.*\.json/).and_return(false)
          allow(scanner).to receive(:`).and_return(flay_output)
          allow(File).to receive(:delete).and_return(true)
        end

        it 'creates scans for duplicated code' do
          scanner.scan

          scans = scanned_app.quality_scans.where(scan_type: "flay")
          flay_scan = scans.find { |s| s.message.include?("Similar code found") }

          expect(flay_scan).to be_present
          expect(flay_scan.severity).to eq("low")
        end
      end

      describe 'summary creation' do
        let(:output_file) { Rails.root.join("tmp", "reek_#{scanned_app.name}.json") }
        let(:reek_output) do
          [
            {
              "source" => "app/models/user.rb",
              "smells" => [
                {
                  "smell_type" => "FeatureEnvy",
                  "message" => "User has feature envy",
                  "lines" => [10]
                }
              ]
            }
          ]
        end

        let(:flog_output) do
          <<~OUTPUT
            app/models/user.rb: (45.2)
               45.2:  User#complex_method
            app/services/processor.rb: (25.0)
               25.0:  Processor#process
          OUTPUT
        end

        let(:flay_output) do
          <<~OUTPUT
            Similar code found in :defn (mass = 50)
              app/models/user.rb:25
          OUTPUT
        end

        before do
          allow(scanner).to receive(:system).and_return(true)
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(output_file).and_return(true)
          allow(File).to receive(:read).with(output_file).and_return(reek_output.to_json)
          allow(File).to receive(:delete).and_return(true)

          # Mock backtick calls for flog and flay - return values in order
          allow(scanner).to receive(:`).and_return(flog_output, flay_output)
        end

        it 'creates metric summary with correct counts' do
          scanner.scan

          # Should create separate summaries for each tool
          reek_summary = scanned_app.metric_summaries.find_by(scan_type: "reek")
          flog_summary = scanned_app.metric_summaries.find_by(scan_type: "flog")
          flay_summary = scanned_app.metric_summaries.find_by(scan_type: "flay")

          expect(reek_summary).to be_present
          expect(flog_summary).to be_present
          expect(flay_summary).to be_present

          expect(reek_summary.total_issues).to eq(1)
          expect(flog_summary.total_issues).to eq(2)
          expect(flay_summary.total_issues).to eq(1)
        end

        it 'calculates average score from metric_value' do
          scanner.scan

          # Flog has metric_value, should calculate average
          flog_summary = scanned_app.metric_summaries.find_by(scan_type: "flog")
          expect(flog_summary.average_score).to eq(35.1) # (45.2 + 25.0) / 2

          # Reek doesn't use metric_value
          reek_summary = scanned_app.metric_summaries.find_by(scan_type: "reek")
          expect(reek_summary.average_score).to be_nil
        end
      end

      describe 'error handling' do
        let(:output_file) { Rails.root.join("tmp", "reek_#{scanned_app.name}.json") }

        before do
          allow(File).to receive(:directory?).with(scanned_app.path).and_return(true)
          allow(scanner).to receive(:system).and_return(true)
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(output_file).and_return(true)
          allow(File).to receive(:read).with(output_file).and_raise(StandardError.new("Parse error"))
          allow(Rails.logger).to receive(:error)
        end

        it 'logs errors and continues' do
          expect(Rails.logger).to receive(:error).with(/Reek scan failed/)
          scanner.scan
        end
      end
    end
  end
end
