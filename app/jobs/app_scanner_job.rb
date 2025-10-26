class AppScannerJob < ApplicationJob
  queue_as :default

  def perform(app_id)
    app = ScannedApp.find(app_id)

    Rails.logger.info("Starting quality scan for #{app.name}")

    # Run all scanners
    SecurityScanner.new(app).scan
    StaticAnalysisScanner.new(app).scan
    RubocopScanner.new(app).scan
    DriftScanner.new(app).scan
    # Note: Skipping test coverage for now as it can be slow

    # Update app status based on scan results
    update_app_status(app)

    Rails.logger.info("Completed quality scan for #{app.name}")
  end

  private

  def update_app_status(app)
    critical_count = app.quality_scans.where(severity: ["critical", "high"]).count
    medium_count = app.quality_scans.where(severity: "medium").count

    app.update!(
      last_scanned_at: Time.current,
      status: determine_status(critical_count, medium_count)
    )
  end

  def determine_status(critical_count, medium_count)
    return "critical" if critical_count > 0
    return "warning" if medium_count > 5
    "healthy"
  end
end
