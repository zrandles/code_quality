require 'rails_helper'

RSpec.describe TestCoverageScanner do
  let(:app) { create(:app, path: "/tmp/test_app") }
  let(:scanner) { described_class.new(app) }

  describe '#scan' do
    context 'when app directory does not exist' do
      before do
        allow(File).to receive(:directory?).with(app.path).and_return(false)
      end

      it 'does not run coverage scan' do
        expect(scanner).not_to receive(:run_test_suite)
        scanner.scan
      end
    end

    context 'when app directory exists' do
      before do
        allow(File).to receive(:directory?).with(app.path).and_return(true)
      end

      describe 'parsing existing coverage results' do
        let(:coverage_data) do
          {
            "RSpec" => {
              "coverage" => {
                "/tmp/test_app/app/models/user.rb" => [1, 1, 1, nil, 1, 0, 0, 1, 1, 1],
                "/tmp/test_app/app/controllers/users_controller.rb" => [1, 1, 1, 1, 1, 1],
                "/tmp/test_app/test/user_test.rb" => [1, 1, 1] # Should be ignored
              }
            }
          }
        end

        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/coverage\/\.resultset\.json/).and_return(true)
          allow(File).to receive(:read).with(/coverage\/\.resultset\.json/).and_return(coverage_data.to_json)
          allow(File).to receive(:exist?).with(/test/).and_return(false)
        end

        it 'parses SimpleCov results and creates quality scans' do
          scanner.scan

          scans = app.quality_scans.where(scan_type: "test_coverage")
          expect(scans.count).to be > 0
        end

        it 'flags files with coverage below 80%' do
          scanner.scan

          low_coverage_scan = app.quality_scans.find { |s| s.file_path.include?("user.rb") }
          expect(low_coverage_scan).to be_present
          expect(low_coverage_scan.severity).to eq("high") # < 50%
        end

        it 'does not flag files with coverage >= 80%' do
          scanner.scan

          users_controller_scan = app.quality_scans.find do |s|
            s.file_path.include?("users_controller.rb") && s.severity != "info"
          end
          expect(users_controller_scan).to be_nil # 100% coverage
        end

        it 'stores overall coverage as info scan' do
          scanner.scan

          overall_scan = app.quality_scans.find_by(severity: "info")
          expect(overall_scan).to be_present
          expect(overall_scan.message).to include("Overall test coverage")
          expect(overall_scan.metric_value).to be_a(Float)
        end

        it 'ignores test files from coverage calculation' do
          scanner.scan

          test_file_scan = app.quality_scans.find { |s| s.file_path&.include?("test/") }
          expect(test_file_scan).to be_nil
        end

        it 'creates metric summary with coverage data' do
          scanner.scan

          summary = app.metric_summaries.find_by(scan_type: "test_coverage")
          expect(summary).to be_present
          expect(summary.average_score).to be_a(Float)
          expect(summary.metadata["overall_coverage"]).to be_present
        end

        it 'sets severity based on coverage percentage' do
          scanner.scan

          # User.rb has 6 covered out of 9 lines = 66.67%
          # Should be "medium" (not < 50%, so not high)
          medium_scan = app.quality_scans.find do |s|
            s.file_path.include?("user.rb") && s.severity == "medium"
          end
          expect(medium_scan).to be_present if app.quality_scans.where(scan_type: "test_coverage").count > 1
        end
      end

      describe 'running test suite when coverage file missing' do
        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/coverage\/\.resultset\.json/).and_return(false)
          allow(File).to receive(:exist?).with(%r{/tmp/test_app/test}).and_return(true)
          allow(scanner).to receive(:system).and_return(true)
        end

        it 'runs test suite to generate coverage' do
          expect(scanner).to receive(:system).with(/bin\/rails test/)
          scanner.scan
        end

        it 'uses timeout to prevent hanging' do
          expect(scanner).to receive(:system).with(/timeout 60/)
          scanner.scan
        end
      end

      describe 'when test directory does not exist' do
        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/coverage\/\.resultset\.json/).and_return(false)
          allow(File).to receive(:exist?).with(/test/).and_return(false)
        end

        it 'does not attempt to run tests' do
          expect(scanner).not_to receive(:system)
          scanner.scan
        end
      end

      describe 'summary creation' do
        let(:coverage_data) do
          {
            "RSpec" => {
              "coverage" => {
                "/tmp/test_app/app/models/user.rb" => [1, 1, 1, 1, 1]
              }
            }
          }
        end

        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/coverage\/\.resultset\.json/).and_return(true)
          allow(File).to receive(:read).with(/coverage\/\.resultset\.json/).and_return(coverage_data.to_json)
          allow(File).to receive(:exist?).with(/test/).and_return(false)
        end

        it 'excludes info scans from total_issues count' do
          scanner.scan

          summary = app.metric_summaries.find_by(scan_type: "test_coverage")
          info_count = app.quality_scans.where(scan_type: "test_coverage", severity: "info").count

          expect(summary.total_issues).to eq(app.quality_scans.where(scan_type: "test_coverage").count - info_count)
        end

        it 'stores overall coverage in metadata' do
          scanner.scan

          summary = app.metric_summaries.find_by(scan_type: "test_coverage")
          expect(summary.metadata).to have_key("overall_coverage")
        end
      end

      describe 'error handling' do
        before do
          allow(File).to receive(:directory?).with(app.path).and_return(true)
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/coverage\/\.resultset\.json/).and_return(true)
          allow(File).to receive(:read).and_raise(StandardError.new("Parse error"))
          allow(Rails.logger).to receive(:error)
        end

        it 'logs errors and continues' do
          expect(Rails.logger).to receive(:error).with(/Test coverage scan failed/)
          scanner.scan
        end
      end
    end
  end
end
