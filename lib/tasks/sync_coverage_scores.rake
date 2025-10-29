namespace :quality do
  desc "Sync coverage scores from coverage files to MetricSummaries"
  task sync_coverage_scores: :environment do
    ScannedApp.where.not(status: "paused").find_each do |app|
      # Try .last_run.json first (simpler format)
      last_run_file = File.join(app.path, "coverage", ".last_run.json")
      resultset_file = File.join(app.path, "coverage", ".resultset.json")

      coverage_pct = nil

      if File.exist?(last_run_file)
        begin
          data = JSON.parse(File.read(last_run_file))
          coverage_pct = data.dig("result", "line")
        rescue => e
          puts "✗ #{app.name}: Error parsing .last_run.json - #{e.message}"
        end
      elsif File.exist?(resultset_file)
        # Parse .resultset.json (more complex format)
        begin
          data = JSON.parse(File.read(resultset_file))
          # .resultset.json contains coverage data per file
          # Calculate overall line coverage
          total_lines = 0
          covered_lines = 0

          data.each do |_key, result|
            next unless result['coverage']

            result['coverage'].each do |file_path, line_coverage|
              next unless line_coverage.is_a?(Hash) && line_coverage['lines']

              line_coverage['lines'].each do |count|
                total_lines += 1 if count # Line is relevant (not nil)
                covered_lines += 1 if count && count > 0
              end
            end
          end

          coverage_pct = total_lines > 0 ? ((covered_lines.to_f / total_lines) * 100).round(2) : nil
        rescue => e
          puts "✗ #{app.name}: Error parsing .resultset.json - #{e.message}"
        end
      end

      if coverage_pct
        summary = app.metric_summaries.find_or_initialize_by(scan_type: "test_coverage")
        summary.average_score = coverage_pct.to_f.round(2)
        summary.scanned_at = Time.current
        summary.metadata ||= {}
        summary.metadata["overall_coverage"] = coverage_pct.to_f.round(2)

        # Count files with low coverage as "issues"
        # For now, just set to 0 if coverage is good, calculate later if needed
        summary.total_issues ||= 0
        summary.high_severity ||= 0
        summary.medium_severity ||= 0
        summary.low_severity ||= 0

        summary.save!
        puts "✓ #{app.name}: Updated coverage to #{coverage_pct}%"
      else
        puts "- #{app.name}: No coverage file found"
      end
    end

    puts "\nCoverage sync complete!"
  end
end
