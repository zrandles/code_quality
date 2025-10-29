class DashboardController < ApplicationController
  def index
    # Sort apps: active apps first (alphabetically), then paused apps (alphabetically)
    @apps = ScannedApp.all.sort_by do |app|
      [app.status == "paused" ? 1 : 0, app.name.downcase]
    end

    @total_apps = @apps.count
    @critical_apps = @apps.select { |app| app.status == "critical" }.count
    @warning_apps = @apps.select { |app| app.status == "warning" }.count

    # Get overall statistics
    @total_issues = QualityScan.count
    @critical_issues = QualityScan.where(severity: ["critical", "high"]).count

    # Recent scans
    @recent_scans = QualityScan.order(scanned_at: :desc).limit(10).includes(:scanned_app)
  end
end
