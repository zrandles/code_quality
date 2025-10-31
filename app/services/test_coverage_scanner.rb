require "shellwords"

class TestCoverageScanner
  attr_reader :app, :results

  def initialize(app)
    @app = app
    @results = []
  end

  def scan
    return unless app_exists?

    run_tests_with_coverage
    save_results
  end

  private

  def app_exists?
    File.directory?(app.path)
  end

  def run_tests_with_coverage
    coverage_file = File.join(app.path, "coverage", ".resultset.json")

    # Check if coverage results already exist
    if File.exist?(coverage_file)
      parse_coverage_results(coverage_file)
    else
      # Run tests to generate coverage (if test suite exists)
      if File.exist?(File.join(app.path, "test"))
        run_test_suite
        parse_coverage_results(coverage_file) if File.exist?(coverage_file)
      end
    end
  rescue => e
    Rails.logger.error("Test coverage scan failed for #{app.name}: #{e.message}")
  end

  def run_test_suite
    # This will run the tests and generate SimpleCov results
    # We're using timeout to prevent hanging
    # Sanitize path to prevent command injection
    app_path = Shellwords.escape(app.path)
    cmd = "cd #{app_path} && timeout 60 bin/rails test 2>&1"
    system(cmd)
  end

  def parse_coverage_results(coverage_file)
    data = JSON.parse(File.read(coverage_file))

    # SimpleCov stores results by test type
    test_data = data.values.first
    return unless test_data

    coverage = test_data["coverage"]
    total_lines = 0
    covered_lines = 0

    coverage.each do |file_path, line_coverage|
      next if file_path.include?("test/") # Skip test files

      file_total = line_coverage.compact.size
      file_covered = line_coverage.count { |l| l && l > 0 }

      total_lines += file_total
      covered_lines += file_covered

      # Flag files with low coverage
      if file_total > 0
        file_coverage_pct = (file_covered.to_f / file_total * 100).round(2)

        if file_coverage_pct < 80
          @results << {
            scan_type: "test_coverage",
            severity: file_coverage_pct < 50 ? "high" : "medium",
            message: "Low test coverage: #{file_coverage_pct}%",
            file_path: file_path,
            metric_value: file_coverage_pct,
            scanned_at: Time.current
          }
        end
      end
    end

    # Store overall coverage
    overall_coverage = total_lines > 0 ? (covered_lines.to_f / total_lines * 100).round(2) : 0

    @results << {
      scan_type: "test_coverage",
      severity: "info",
      message: "Overall test coverage: #{overall_coverage}%",
      metric_value: overall_coverage,
      scanned_at: Time.current
    }
  end

  def save_results
    # Clear old coverage scans
    app.quality_scans.where(scan_type: "test_coverage").delete_all

    # Create new scans
    @results.each do |result|
      app.quality_scans.create!(result)
    end

    # Create summary
    create_summary
  end

  def create_summary
    scans = app.quality_scans.where(scan_type: "test_coverage")
    overall = scans.find_by(severity: "info")

    app.metric_summaries.find_or_initialize_by(scan_type: "test_coverage").tap do |summary|
      summary.total_issues = scans.where.not(severity: "info").count
      summary.high_severity = scans.where(severity: "high").count
      summary.medium_severity = scans.where(severity: "medium").count
      summary.low_severity = scans.where(severity: "low").count
      summary.average_score = overall&.metric_value || 0.0
      summary.scanned_at = Time.current
      summary.metadata = { overall_coverage: overall&.metric_value }
      summary.save!
    end
  end
end
