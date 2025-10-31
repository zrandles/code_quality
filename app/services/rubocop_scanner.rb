require "shellwords"

class RubocopScanner
  include ScannerBase

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

  def scan
    return unless app_exists?

    run_rubocop
    save_results
  end

  private

  def scan_type
    "rubocop"
  end

  def run_rubocop
    # Sanitize app name for safe filename usage
    safe_name = app.name.gsub(/[^a-zA-Z0-9_-]/, "_")
    output_file = Rails.root.join("tmp", "rubocop_#{safe_name}.json")

    # Validate that app.path exists and is a directory
    return unless app_exists?

    # Build safe target path
    target_path = File.join(app.path, "app")
    return unless File.directory?(target_path)

    # Build command as array to prevent command injection
    # Array-based system calls don't use shell interpretation
    cmd = ["bundle", "exec", "rubocop"]

    # Add each cop as separate arguments
    HIGH_VALUE_COPS.each do |cop|
      cmd << "--only" << cop
    end

    # Add output format and file
    cmd << "--format" << "json"
    cmd << "--out" << output_file.to_s

    # Add target path as separate argument (no interpolation in array)
    cmd << target_path

    # brakeman:ignore:Execute - False positive: array-based system calls are safe
    # Array form doesn't use shell interpretation, and File.join is a safe Ruby method
    system(*cmd, out: File::NULL, err: File::NULL)

    return unless File.exist?(output_file)

    data = JSON.parse(File.read(output_file))
    parse_rubocop_results(data)

    File.delete(output_file)
  rescue StandardError => error
    Rails.logger.error("RuboCop scan failed for #{app.name}: #{error.message}")
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

  # save_results and create_summary are now provided by ScannerBase
end
