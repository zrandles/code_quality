# frozen_string_literal: true

# Shared functionality for all scanner services
# Provides common patterns for saving results and creating metric summaries
module ScannerBase
  extend ActiveSupport::Concern

  included do
    attr_reader :app, :results
  end

  def initialize(app)
    @app = app
    @results = []
  end

  private

  def app_exists?
    File.directory?(app.path)
  end

  # Common pattern: save scan results and create summary
  # Override scan_types if you need multiple types (e.g., ["reek", "flog", "flay"])
  def save_results(scan_types: nil)
    scan_types ||= [scan_type]

    # Clear old scans
    app.quality_scans.where(scan_type: scan_types).delete_all

    # Create new scans
    @results.each do |result|
      app.quality_scans.create!(result)
    end

    # Create summary (or summaries for multiple types)
    create_summary
  end

  # Common pattern: create metric summary from scans
  # Can be overridden for custom logic (e.g., TestCoverageScanner)
  def create_summary_for_type(type)
    scans = app.quality_scans.where(scan_type: type)

    app.metric_summaries.find_or_initialize_by(scan_type: type).tap do |summary|
      summary.total_issues = scans.count
      summary.high_severity = scans.where(severity: ["critical", "high"]).count
      summary.medium_severity = scans.where(severity: "medium").count
      summary.low_severity = scans.where(severity: "low").count
      summary.scanned_at = Time.current
      summary.save!
    end
  end

  # Default scan_type - override in individual scanners if needed
  def scan_type
    raise NotImplementedError, "#{self.class} must implement scan_type method"
  end

  # Default create_summary - override if you need custom logic
  def create_summary
    create_summary_for_type(scan_type)
  end
end
