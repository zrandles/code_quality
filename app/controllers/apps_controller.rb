class AppsController < ApplicationController
  before_action :set_app, only: [:show, :scan]

  def index
    @apps = ScannedApp.all.order(:name)
  end

  def show
    @summaries = @app.metric_summaries.order(scan_type: :asc)
    @recent_scans = @app.quality_scans.order(scanned_at: :desc, severity: :asc).limit(50)

    # Group scans by type for tabs
    @scans_by_type = @app.quality_scans.group_by(&:scan_type)
  end

  def scan
    AppScannerJob.perform_later(@app.id)

    redirect_to app_path(@app), notice: "Scan started for #{@app.name}"
  end

  def discover
    discover_apps
    redirect_to apps_path, notice: "Discovered #{ScannedApp.count} apps"
  end

  private

  def set_app
    @app = ScannedApp.find(params[:id])
  end

  def discover_apps
    apps_dir = File.expand_path("~/zac_ecosystem/apps")

    Dir.glob("#{apps_dir}/*").each do |app_path|
      next unless File.directory?(app_path)

      app_name = File.basename(app_path)

      # Skip non-Rails apps
      next unless File.exist?(File.join(app_path, "config", "application.rb"))

      ScannedApp.find_or_create_by(name: app_name) do |app|
        app.path = app_path
        app.status = "pending"
      end
    end
  end
end
