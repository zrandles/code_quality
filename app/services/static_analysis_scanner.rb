class StaticAnalysisScanner
  attr_reader :app, :results

  def initialize(app)
    @app = app
    @results = []
  end

  def scan
    return unless app_exists?

    run_reek
    run_flog
    run_flay
    save_results
  end

  private

  def app_exists?
    File.directory?(app.path)
  end

  def run_reek
    output_file = Rails.root.join("tmp", "reek_#{app.name}.json")

    cmd = "cd #{app.path} && bundle exec reek app --format json > #{output_file} 2>&1"
    system(cmd)

    return unless File.exist?(output_file)

    data = JSON.parse(File.read(output_file))
    parse_reek_results(data)

    File.delete(output_file)
  rescue => e
    Rails.logger.error("Reek scan failed for #{app.name}: #{e.message}")
  end

  def parse_reek_results(data)
    return unless data.is_a?(Array)

    data.each do |file_data|
      next unless file_data["smells"].is_a?(Array)

      file_data["smells"].each do |smell|
        @results << {
          scan_type: "static_analysis",
          severity: "medium",
          message: "#{smell['smell_type']}: #{smell['message']}",
          file_path: file_data["source"],
          line_number: smell["lines"]&.first,
          scanned_at: Time.current
        }
      end
    end
  end

  def run_flog
    output = `cd #{app.path} && bundle exec flog app 2>&1`
    parse_flog_results(output)
  rescue => e
    Rails.logger.error("Flog scan failed for #{app.name}: #{e.message}")
  end

  def parse_flog_results(output)
    lines = output.split("\n")
    current_file = nil

    lines.each do |line|
      # Parse file paths
      if line.match?(/^\s*\d+\.\d+:\s+(.+)#/)
        complexity = line.match(/^\s*(\d+\.\d+):/)[1].to_f
        method_info = line.match(/:\s+(.+)/)[1]

        if complexity > 20 # Only flag high complexity
          @results << {
            scan_type: "static_analysis",
            severity: complexity > 40 ? "high" : "medium",
            message: "High complexity (#{complexity.round(1)}): #{method_info}",
            file_path: current_file,
            metric_value: complexity,
            scanned_at: Time.current
          }
        end
      elsif line.match?(/^(.+):\s+\(/)
        current_file = line.match(/^(.+):\s+\(/)[1]
      end
    end
  end

  def run_flay
    output = `cd #{app.path} && bundle exec flay app 2>&1`
    parse_flay_results(output)
  rescue => e
    Rails.logger.error("Flay scan failed for #{app.name}: #{e.message}")
  end

  def parse_flay_results(output)
    lines = output.split("\n")

    lines.each do |line|
      # Look for duplicated code
      if line.match?(/Similar code found/)
        @results << {
          scan_type: "static_analysis",
          severity: "low",
          message: line.strip,
          scanned_at: Time.current
        }
      elsif match = line.match(/(.+\.rb):(\d+)/)
        # File locations for duplicated code
        @results.last[:file_path] ||= match[1] if @results.any?
        @results.last[:line_number] ||= match[2].to_i if @results.any?
      end
    end
  end

  def save_results
    # Clear old static analysis scans
    app.quality_scans.where(scan_type: "static_analysis").delete_all

    # Create new scans
    @results.each do |result|
      app.quality_scans.create!(result)
    end

    # Create summary
    create_summary
  end

  def create_summary
    scans = app.quality_scans.where(scan_type: "static_analysis")

    app.metric_summaries.find_or_initialize_by(scan_type: "static_analysis").tap do |summary|
      summary.total_issues = scans.count
      summary.high_severity = scans.where(severity: ["critical", "high"]).count
      summary.medium_severity = scans.where(severity: "medium").count
      summary.low_severity = scans.where(severity: "low").count
      summary.average_score = scans.average(:metric_value).to_f.round(2)
      summary.scanned_at = Time.current
      summary.save!
    end
  end
end
