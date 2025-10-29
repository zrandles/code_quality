class RubocopScanner
  attr_reader :app, :results

  # Only high-value cops - no style nitpicking
  HIGH_VALUE_COPS = %w[
    Lint/Debugger
    Lint/UnusedMethodArgument
    Lint/UnusedBlockArgument
    Lint/UselessAssignment
    Lint/ShadowingOuterLocalVariable
    Lint/AmbiguousOperator
    Lint/Void
    Security/Eval
    Security/Open
    Security/MarshalLoad
    Performance/RegexpMatch
    Performance/StringReplacement
    Performance/RedundantMerge
    Rails/OutputSafety
    Rails/UniqBeforePluck
    Rails/FindEach
    Rails/HasManyOrHasOneDependent
  ].freeze

  def initialize(app)
    @app = app
    @results = []
  end

  def scan
    return unless app_exists?

    run_rubocop
    save_results
  end

  private

  def app_exists?
    File.directory?(app.path)
  end

  def run_rubocop
    output_file = Rails.root.join("tmp", "rubocop_#{app.name}.json")

    # Only run specific cops
    cops_arg = HIGH_VALUE_COPS.map { |cop| "--only #{cop}" }.join(" ")
    cmd = "cd #{app.path} && bundle exec rubocop #{cops_arg} --format json --out #{output_file} app 2>&1"
    system(cmd)

    return unless File.exist?(output_file)

    data = JSON.parse(File.read(output_file))
    parse_rubocop_results(data)

    File.delete(output_file)
  rescue => e
    Rails.logger.error("RuboCop scan failed for #{app.name}: #{e.message}")
  end

  def parse_rubocop_results(data)
    files = data["files"] || []

    files.each do |file_data|
      next unless file_data["offenses"].is_a?(Array)

      file_data["offenses"].each do |offense|
        @results << {
          scan_type: "rubocop",
          severity: rubocop_severity(offense["severity"]),
          message: "#{offense['cop_name']}: #{offense['message']}",
          file_path: file_data["path"],
          line_number: offense.dig("location", "start_line"),
          scanned_at: Time.current
        }
      end
    end
  end

  def rubocop_severity(severity)
    case severity&.downcase
    when "error", "fatal" then "high"
    when "warning" then "medium"
    else "low"
    end
  end

  def save_results
    # Clear old rubocop scans
    app.quality_scans.where(scan_type: "rubocop").delete_all

    # Create new scans
    @results.each do |result|
      app.quality_scans.create!(result)
    end

    # Create summary
    create_summary
  end

  def create_summary
    scans = app.quality_scans.where(scan_type: "rubocop")

    app.metric_summaries.find_or_initialize_by(scan_type: "rubocop").tap do |summary|
      summary.total_issues = scans.count
      summary.high_severity = scans.where(severity: ["critical", "high"]).count
      summary.medium_severity = scans.where(severity: "medium").count
      summary.low_severity = scans.where(severity: "low").count
      summary.scanned_at = Time.current
      summary.save!
    end
  end
end
