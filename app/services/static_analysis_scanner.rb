require "shellwords"

class StaticAnalysisScanner
  attr_reader :app, :results

  def initialize(app)
    @app = app
    @results = []
    @reek_results = []
    @flog_results = []
    @flay_results = []
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
    # Sanitize app name for safe filename usage
    safe_name = app.name.gsub(/[^a-zA-Z0-9_-]/, "_")
    output_file = Rails.root.join("tmp", "reek_#{safe_name}.json")

    # Sanitize paths to prevent command injection
    app_path = Shellwords.escape("#{app.path}/app")
    output_path = Shellwords.escape(output_file.to_s)

    cmd = "bundle exec reek #{app_path} --format json > #{output_path} 2>&1"
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
        result = {
          scan_type: "reek",
          severity: "medium",
          message: "#{smell['smell_type']}: #{smell['message']}",
          file_path: file_data["source"],
          line_number: smell["lines"]&.first,
          scanned_at: Time.current
        }
        @results << result
        @reek_results << result
      end
    end
  end

  def run_flog
    # Sanitize path to prevent command injection
    app_path = Shellwords.escape("#{app.path}/app")
    output = `bundle exec flog #{app_path} 2>&1`
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

        result = {
          scan_type: "flog",
          severity: complexity > 40 ? "high" : (complexity > 20 ? "medium" : "low"),
          message: "Complexity (#{complexity.round(1)}): #{method_info}",
          file_path: current_file,
          metric_value: complexity,
          scanned_at: Time.current
        }
        @results << result
        @flog_results << result
      elsif line.match?(/^(.+):\s+\(/)
        current_file = line.match(/^(.+):\s+\(/)[1]
      end
    end
  end

  def run_flay
    # Sanitize path to prevent command injection
    app_path = Shellwords.escape("#{app.path}/app")
    output = `bundle exec flay #{app_path} 2>&1`
    parse_flay_results(output)
  rescue => e
    Rails.logger.error("Flay scan failed for #{app.name}: #{e.message}")
  end

  def parse_flay_results(output)
    lines = output.split("\n")

    lines.each do |line|
      # Look for duplicated code
      if line.match?(/Similar code found/)
        result = {
          scan_type: "flay",
          severity: "low",
          message: line.strip,
          scanned_at: Time.current
        }
        @results << result
        @flay_results << result
      elsif match = line.match(/(.+\.rb):(\d+)/)
        # File locations for duplicated code
        @results.last[:file_path] ||= match[1] if @results.any?
        @results.last[:line_number] ||= match[2].to_i if @results.any?
        @flay_results.last[:file_path] ||= match[1] if @flay_results.any?
        @flay_results.last[:line_number] ||= match[2].to_i if @flay_results.any?
      end
    end
  end

  def save_results
    # Clear old static analysis scans (including new scan types)
    app.quality_scans.where(scan_type: ["static_analysis", "reek", "flog", "flay"]).delete_all

    # Create new scans
    @results.each do |result|
      app.quality_scans.create!(result)
    end

    # Create summaries for each tool
    create_summaries
  end

  def create_summaries
    # Create Reek summary (code smells)
    create_reek_summary

    # Create Flog summary (complexity)
    create_flog_summary

    # Create Flay summary (duplication)
    create_flay_summary
  end

  def create_reek_summary
    scans = app.quality_scans.where(scan_type: "reek")

    app.metric_summaries.find_or_initialize_by(scan_type: "reek").tap do |summary|
      summary.total_issues = scans.count
      summary.high_severity = scans.where(severity: ["critical", "high"]).count
      summary.medium_severity = scans.where(severity: "medium").count
      summary.low_severity = scans.where(severity: "low").count
      summary.average_score = nil # Not applicable for code smells
      summary.scanned_at = Time.current
      summary.save!
    end
  end

  def create_flog_summary
    scans = app.quality_scans.where(scan_type: "flog")

    app.metric_summaries.find_or_initialize_by(scan_type: "flog").tap do |summary|
      summary.total_issues = scans.count
      summary.high_severity = scans.where(severity: ["critical", "high"]).count
      summary.medium_severity = scans.where(severity: "medium").count
      summary.low_severity = scans.where(severity: "low").count
      summary.average_score = scans.average(:metric_value).to_f.round(2)
      summary.scanned_at = Time.current
      summary.save!
    end
  end

  def create_flay_summary
    scans = app.quality_scans.where(scan_type: "flay")

    app.metric_summaries.find_or_initialize_by(scan_type: "flay").tap do |summary|
      summary.total_issues = scans.count
      summary.high_severity = scans.where(severity: ["critical", "high"]).count
      summary.medium_severity = scans.where(severity: "medium").count
      summary.low_severity = scans.where(severity: "low").count
      summary.average_score = nil # Not applicable for duplications
      summary.scanned_at = Time.current
      summary.save!
    end
  end
end
