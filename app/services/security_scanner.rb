require "shellwords"

class SecurityScanner
  include ScannerBase

  def scan
    return unless app_exists?

    run_brakeman
    save_results
  end

  private

  def scan_type
    "security"
  end

  def run_brakeman
    # Sanitize app name for safe filename usage
    safe_name = app.name.gsub(/[^a-zA-Z0-9_-]/, "_")
    output_file = Rails.root.join("tmp", "brakeman_#{safe_name}.json")

    # Sanitize paths to prevent command injection
    app_path = Shellwords.escape(app.path)
    output_path = Shellwords.escape(output_file.to_s)

    # Run brakeman from code_quality's bundle, pointing at target app
    cmd = "bundle exec brakeman #{app_path} -q -f json -o #{output_path} 2>&1"
    system(cmd)

    return unless File.exist?(output_file)

    data = JSON.parse(File.read(output_file))
    parse_brakeman_results(data)

    File.delete(output_file) if File.exist?(output_file)
  rescue StandardError => error
    Rails.logger.error("Brakeman scan failed for #{app.name}: #{error.message}")
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

  # save_results and create_summary are now provided by ScannerBase
end
