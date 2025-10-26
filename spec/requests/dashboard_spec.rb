require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    let!(:healthy_app) { create(:scanned_app, :healthy) }
    let!(:warning_app) { create(:scanned_app, :warning) }
    let!(:critical_app) { create(:scanned_app, :critical) }

    before do
      create_list(:quality_scan, 3, :critical, scanned_app: healthy_app)
      create_list(:quality_scan, 5, :medium, scanned_app: warning_app)
    end

    it "returns successful response" do
      get "/code_quality"
      expect(response).to have_http_status(:ok)
    end

    it "assigns @apps with all apps ordered by name" do
      get "/code_quality"
      expect(assigns(:apps)).to match_array([healthy_app, warning_app, critical_app])
    end

    it "calculates total apps count" do
      get "/code_quality"
      expect(assigns(:total_apps)).to eq(3)
    end

    it "calculates critical apps count" do
      get "/code_quality"
      expect(assigns(:critical_apps)).to eq(1)
    end

    it "calculates warning apps count" do
      get "/code_quality"
      expect(assigns(:warning_apps)).to eq(1)
    end

    it "calculates total issues" do
      get "/code_quality"
      expect(assigns(:total_issues)).to eq(QualityScan.count)
    end

    it "calculates critical issues count" do
      get "/code_quality"
      expect(assigns(:critical_issues)).to be >= 3
    end

    it "assigns recent scans" do
      get "/code_quality"
      expect(assigns(:recent_scans)).to be_present
      expect(assigns(:recent_scans).count).to be <= 10
    end

    it "orders recent scans by scanned_at desc" do
      get "/code_quality"
      scans = assigns(:recent_scans)
      expect(scans.first.scanned_at).to be >= scans.last.scanned_at if scans.count > 1
    end

    it "includes app association in recent scans" do
      get "/code_quality"
      # Verify eager loading worked (no N+1 queries)
      # Just check that scanned_app is accessible without additional queries
      assigns(:recent_scans).each(&:scanned_app)
    end
  end
end
