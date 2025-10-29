class SecurityScanner
  attr_reader :app, :results

  def initialize(app)
    @app = app
    @results = []
  end

  def scan
    return unless app_exists?

    run_brakeman
    save_results
  end

  private

  def app_exists?
    File.directory?(app.path)
  end

  def run_brakeman
    output_file = Rails.root.join("tmp", "brakeman_#{app.name}.json")

    # Run brakeman with JSON output
    cmd = "cd #{app.path} && bundle exec brakeman -q -f json -o #{output_file} 2>&1"
    system(cmd)

    return unless File.exist?(output_file)

    data = JSON.parse(File.read(output_file))
    parse_brakeman_results(data)

    File.delete(output_file) if File.exist?(output_file)
  rescue => e
    Rails.logger.error("Brakeman scan failed for #{app.name}: #{e.message}")
  end

  def parse_brakeman_results(data)
    warnings = data["warnings"] || []

    warnings.each do |warning|
      @results << {
        scan_type: "security",
        severity: severity_for_confidence(warning["confidence"]),
        message: "#{warning['warning_type']}: #{warning['message']}",
        file_path: warning["file"],
        line_number: warning["line"],
        scanned_at: Time.current
      }
    end
  end

  def severity_for_confidence(confidence)
    case confidence&.downcase
    when "high" then "critical"
    when "medium" then "high"
    when "weak" then "medium"
    else "low"
    end
  end

  def save_results
    # Clear old security scans for this app
    app.quality_scans.where(scan_type: "security").delete_all

    # Create new scans
    @results.each do |result|
      app.quality_scans.create!(result)
    end

    # Create summary
    create_summary
  end

  def create_summary
    scans = app.quality_scans.where(scan_type: "security")

    app.metric_summaries.find_or_initialize_by(scan_type: "security").tap do |summary|
      summary.total_issues = scans.count
      summary.high_severity = scans.where(severity: ["critical", "high"]).count
      summary.medium_severity = scans.where(severity: "medium").count
      summary.low_severity = scans.where(severity: "low").count
      summary.scanned_at = Time.current
      summary.save!
    end
  end
end
