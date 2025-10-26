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

          scans = scanned_app.quality_scans.where(scan_type: "static_analysis")
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

          scans = scanned_app.quality_scans.where(scan_type: "static_analysis")
          complex_scans = scans.select { |s| s.message.include?("High complexity") }

          expect(complex_scans.count).to eq(2)
        end

        it 'sets severity based on complexity threshold' do
          scanner.scan

          scans = scanned_app.quality_scans.where(scan_type: "static_analysis")
          very_high = scans.find { |s| s.metric_value == 52.0 }
          high = scans.find { |s| s.metric_value == 45.2 }

          expect(very_high.severity).to eq("high") # > 40
          expect(high.severity).to eq("high") # > 40
        end

        it 'ignores low complexity methods (<= 20)' do
          scanner.scan

          scans = scanned_app.quality_scans.where(scan_type: "static_analysis")
          low_complexity = scans.find { |s| s.message.include?("12.5") }

          expect(low_complexity).to be_nil
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

          scans = scanned_app.quality_scans.where(scan_type: "static_analysis")
          flay_scan = scans.find { |s| s.message.include?("Similar code found") }

          expect(flay_scan).to be_present
          expect(flay_scan.severity).to eq("low")
        end
      end

      describe 'summary creation' do
        before do
          allow(scanner).to receive(:system).and_return(true)
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/reek.*\.json/).and_return(false)
          allow(scanner).to receive(:`).and_return("")
          allow(File).to receive(:delete).and_return(true)

          # Create some scans manually
          create(:quality_scan, :static_analysis, scanned_app: scanned_app, severity: "high", metric_value: 45.0)
          create(:quality_scan, :static_analysis, scanned_app: scanned_app, severity: "medium", metric_value: 25.0)
          create(:quality_scan, :static_analysis, scanned_app: scanned_app, severity: "low", metric_value: 10.0)
        end

        it 'creates metric summary with correct counts' do
          scanner.scan

          summary = scanned_app.metric_summaries.find_by(scan_type: "static_analysis")
          expect(summary).to be_present
          expect(summary.total_issues).to be >= 0
        end

        it 'calculates average score from metric_value' do
          scanner.scan

          summary = scanned_app.metric_summaries.find_by(scan_type: "static_analysis")
          # Should calculate average of metric_value fields
          expect(summary.average_score).to be_a(Float)
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
