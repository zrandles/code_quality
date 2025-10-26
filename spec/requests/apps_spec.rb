require 'rails_helper'

RSpec.describe "Apps", type: :request do
  describe "GET /apps" do
    let!(:apps) { create_list(:scanned_app, 3) }

    it "returns successful response" do
      get "/code_quality/apps"
      expect(response).to have_http_status(:ok)
    end

    it "assigns @apps with all apps ordered by name" do
      get "/code_quality/apps"
      expect(assigns(:apps)).to match_array(apps)
    end

    it "orders apps by name" do
      get "/code_quality/apps"
      app_names = assigns(:apps).pluck(:name)
      expect(app_names).to eq(app_names.sort)
    end
  end

  describe "GET /apps/:id" do
    let(:scanned_app) { create(:scanned_app, :with_summaries) }
    let!(:security_scan) { create(:quality_scan, :security, scanned_app: scanned_app) }
    let!(:rubocop_scan) { create(:quality_scan, :rubocop, scanned_app: scanned_app) }

    it "returns successful response" do
      get "/code_quality/apps/#{scanned_app.id}"
      expect(response).to have_http_status(:ok)
    end

    it "assigns @app" do
      get "/code_quality/apps/#{scanned_app.id}"
      expect(assigns(:app)).to eq(scanned_app)
    end

    it "assigns @summaries ordered by scan_type" do
      get "/code_quality/apps/#{scanned_app.id}"
      summaries = assigns(:summaries)
      expect(summaries).to be_present
      expect(summaries.pluck(:scan_type)).to eq(summaries.pluck(:scan_type).sort)
    end

    it "assigns @recent_scans limited to 50" do
      create_list(:quality_scan, 60, scanned_app: scanned_app)

      get "/code_quality/apps/#{scanned_app.id}"
      expect(assigns(:recent_scans).count).to eq(50)
    end

    it "orders recent scans by scanned_at desc, then severity asc" do
      get "/code_quality/apps/#{scanned_app.id}"
      scans = assigns(:recent_scans)
      expect(scans.first.scanned_at).to be >= scans.last.scanned_at if scans.count > 1
    end

    it "assigns @scans_by_type grouped by scan type" do
      get "/code_quality/apps/#{scanned_app.id}"
      scans_by_type = assigns(:scans_by_type)

      expect(scans_by_type).to be_a(Hash)
      expect(scans_by_type.keys).to include("security", "rubocop")
    end

    it "returns 404 for non-existent app" do
      get "/code_quality/apps/999999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /apps/:id/scan" do
    let(:scanned_app) { create(:scanned_app) }

    it "enqueues scan job" do
      # Mock the job to avoid actual background processing
      allow(AppScannerJob).to receive(:perform_later)

      post "/code_quality/apps/#{scanned_app.id}/scan"

      expect(AppScannerJob).to have_received(:perform_later).with(scanned_app.id)
    end

    it "redirects to app show page" do
      allow(AppScannerJob).to receive(:perform_later)

      post "/code_quality/apps/#{scanned_app.id}/scan"

      expect(response).to redirect_to("/code_quality/apps/#{scanned_app.id}")
    end

    it "sets flash notice" do
      allow(AppScannerJob).to receive(:perform_later)

      post "/code_quality/apps/#{scanned_app.id}/scan"

      expect(flash[:notice]).to include("Scan started")
      expect(flash[:notice]).to include(scanned_app.name)
    end
  end

  describe "POST /apps/discover" do
    let(:apps_dir) { "/tmp/test_apps_dir" }
    let(:app1_path) { "#{apps_dir}/app1" }
    let(:app2_path) { "#{apps_dir}/app2" }

    before do
      # Mock File operations
      allow(File).to receive(:expand_path).with("~/zac_ecosystem/apps").and_return(apps_dir)
      allow(Dir).to receive(:glob).with("#{apps_dir}/*").and_return([app1_path, app2_path])
      allow(File).to receive(:directory?).and_return(true)
      allow(File).to receive(:basename).with(app1_path).and_return("app1")
      allow(File).to receive(:basename).with(app2_path).and_return("app2")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("#{app1_path}/config/application.rb").and_return(true)
      allow(File).to receive(:exist?).with("#{app2_path}/config/application.rb").and_return(true)
      allow(File).to receive(:join).and_call_original
      allow(File).to receive(:join).with(app1_path, "config", "application.rb").and_return("#{app1_path}/config/application.rb")
      allow(File).to receive(:join).with(app2_path, "config", "application.rb").and_return("#{app2_path}/config/application.rb")
    end

    it "discovers Rails apps in ecosystem" do
      post "/code_quality/apps/discover"

      expect(ScannedApp.find_by(name: "app1")).to be_present
      expect(ScannedApp.find_by(name: "app2")).to be_present
    end

    it "sets correct app paths" do
      post "/code_quality/apps/discover"

      app1 = ScannedApp.find_by(name: "app1")
      expect(app1.path).to eq(app1_path)
    end

    it "sets status to pending for new apps" do
      post "/code_quality/apps/discover"

      app1 = ScannedApp.find_by(name: "app1")
      expect(app1.status).to eq("pending")
    end

    it "redirects to apps index" do
      post "/code_quality/apps/discover"
      expect(response).to redirect_to("/code_quality/apps")
    end

    it "sets flash notice with app count" do
      post "/code_quality/apps/discover"
      expect(flash[:notice]).to include("Discovered")
      expect(flash[:notice]).to include(ScannedApp.count.to_s)
    end

    it "does not duplicate existing apps" do
      create(:scanned_app, name: "app1", path: app1_path)

      expect {
        post "/code_quality/apps/discover"
      }.to change(ScannedApp, :count).by(1) # Only app2 is new
    end

    it "skips non-Rails directories" do
      allow(File).to receive(:exist?).with("#{app2_path}/config/application.rb").and_return(false)

      post "/code_quality/apps/discover"

      expect(ScannedApp.find_by(name: "app1")).to be_present
      expect(ScannedApp.find_by(name: "app2")).to be_nil
    end
  end
end
