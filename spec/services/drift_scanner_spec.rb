require 'rails_helper'

RSpec.describe DriftScanner do
  let(:app) { create(:app, name: "test_app", path: "/tmp/test_app") }
  let(:scanner) { described_class.new(app) }

  describe '#scan' do
    context 'when app directory does not exist' do
      before do
        allow(File).to receive(:directory?).with(app.path).and_return(false)
      end

      it 'does not perform any checks' do
        expect(scanner).not_to receive(:check_deployment_config)
        scanner.scan
      end
    end

    context 'when app is golden_deployment' do
      let(:golden_app) { create(:app, name: "golden_deployment", path: "/tmp/golden") }
      let(:golden_scanner) { described_class.new(golden_app) }

      before do
        allow(File).to receive(:directory?).with(golden_app.path).and_return(true)
      end

      it 'skips scanning golden_deployment itself' do
        expect(golden_scanner).not_to receive(:check_deployment_config)
        golden_scanner.scan
      end
    end

    context 'when app directory exists' do
      before do
        allow(File).to receive(:directory?).with(app.path).and_return(true)
      end

      describe 'deployment config check' do
        context 'when deploy.rb is missing' do
          before do
            allow(File).to receive(:exist?).with(/deploy\.rb/).and_return(false)
          end

          it 'creates critical drift issue' do
            scanner.scan

            scan = app.quality_scans.find_by(scan_type: "drift")
            expect(scan).to be_present
            expect(scan.severity).to eq("critical")
            expect(scan.message).to include("Missing config/deploy.rb")
          end
        end

        context 'when deploy.rb exists but missing :application setting' do
          let(:deploy_content) { "# Deploy config without :application" }

          before do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(/deploy\.rb/).and_return(true)
            allow(File).to receive(:read).with(/deploy\.rb/).and_return(deploy_content)
            allow(File).to receive(:exist?).with(/Gemfile\.lock/).and_return(false)
            allow(File).to receive(:exist?).with(/production\.rb/).and_return(false)
          end

          it 'creates high severity drift issue' do
            scanner.scan

            scan = app.quality_scans.find { |s| s.message.include?(":application") }
            expect(scan).to be_present
            expect(scan.severity).to eq("high")
          end
        end
      end

      describe 'gem version check' do
        let(:app_gemfile_lock) do
          <<~GEMFILE
            GEM
              remote: https://rubygems.org/
              specs:
                rails (8.0.0)
                puma (6.0.0)
          GEMFILE
        end

        let(:golden_gemfile_lock) do
          <<~GEMFILE
            GEM
              remote: https://rubygems.org/
              specs:
                rails (8.0.1)
                puma (6.0.0)
          GEMFILE
        end

        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/deploy\.rb/).and_return(false)
          allow(File).to receive(:exist?).with(%r{/tmp/test_app/Gemfile\.lock}).and_return(true)
          allow(File).to receive(:exist?).with(/golden_deployment\/Gemfile\.lock/).and_return(true)
          allow(File).to receive(:read).with(%r{/tmp/test_app/Gemfile\.lock}).and_return(app_gemfile_lock)
          allow(File).to receive(:read).with(/golden_deployment\/Gemfile\.lock/).and_return(golden_gemfile_lock)
          allow(File).to receive(:exist?).with(/production\.rb/).and_return(false)
        end

        it 'detects Rails version drift' do
          scanner.scan

          scan = app.quality_scans.find { |s| s.message.include?("Rails version") }
          expect(scan).to be_present
          expect(scan.severity).to eq("medium")
          expect(scan.message).to include("8.0.0")
          expect(scan.message).to include("8.0.1")
        end
      end

      describe 'Tailwind setup check' do
        context 'when production.rb missing Tailwind build task' do
          let(:production_content) { "# Production config without tailwindcss:build" }

          before do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(/deploy\.rb/).and_return(false)
            allow(File).to receive(:exist?).with(/Gemfile\.lock/).and_return(false)
            allow(File).to receive(:exist?).with(/production\.rb/).and_return(true)
            allow(File).to receive(:read).with(/production\.rb/).and_return(production_content)
          end

          it 'creates medium severity drift issue' do
            scanner.scan

            scan = app.quality_scans.find { |s| s.message.include?("Tailwind") }
            expect(scan).to be_present
            expect(scan.severity).to eq("medium")
          end
        end
      end

      describe 'path-based routing check' do
        context 'when production.rb missing relative_url_root' do
          let(:production_content) { "# Production config without relative_url_root" }

          before do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(/deploy\.rb/).and_return(false)
            allow(File).to receive(:exist?).with(/Gemfile\.lock/).and_return(false)
            allow(File).to receive(:exist?).with(/production\.rb/).and_return(true)
            allow(File).to receive(:read).with(/production\.rb/).and_return(production_content)
          end

          it 'creates high severity drift issue' do
            scanner.scan

            scan = app.quality_scans.find { |s| s.message.include?("relative_url_root") }
            expect(scan).to be_present
            expect(scan.severity).to eq("high")
          end
        end

        context 'when relative_url_root is configured' do
          let(:production_content) { 'config.relative_url_root = "/app_name"' }

          before do
            allow(File).to receive(:exist?).and_call_original
            allow(File).to receive(:exist?).with(/deploy\.rb/).and_return(false)
            allow(File).to receive(:exist?).with(/Gemfile\.lock/).and_return(false)
            allow(File).to receive(:exist?).with(/production\.rb/).and_return(true)
            allow(File).to receive(:read).with(/production\.rb/).and_return(production_content)
          end

          it 'does not create drift issue for relative_url_root' do
            scanner.scan

            scan = app.quality_scans.find { |s| s.message.include?("relative_url_root") }
            expect(scan).to be_nil
          end
        end
      end

      describe 'summary creation' do
        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/deploy\.rb/).and_return(false)
          allow(File).to receive(:exist?).with(/Gemfile\.lock/).and_return(false)
          allow(File).to receive(:exist?).with(/production\.rb/).and_return(false)
        end

        it 'creates metric summary for drift scans' do
          scanner.scan

          summary = app.metric_summaries.find_by(scan_type: "drift")
          expect(summary).to be_present
        end

        it 'clears old drift scans before creating new ones' do
          create(:quality_scan, :drift, app: app, message: "Old drift scan")

          scanner.scan

          # After scan, old scan should be deleted
          expect(app.quality_scans.where(scan_type: "drift").pluck(:message)).not_to include("Old drift scan")
        end
      end

      describe 'error handling' do
        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(/deploy\.rb/).and_return(true)
          allow(File).to receive(:read).and_raise(StandardError.new("Read error"))
          allow(Rails.logger).to receive(:error)
        end

        it 'logs errors and continues' do
          expect(Rails.logger).to receive(:error).with(/Drift check failed/)
          scanner.scan
        end
      end
    end
  end

  describe 'CRITICAL_FILES constant' do
    it 'includes deployment configuration files' do
      expect(DriftScanner::CRITICAL_FILES).to include(
        "config/deploy.rb",
        "config/deploy/production.rb",
        "config/environments/production.rb"
      )
    end
  end
end
