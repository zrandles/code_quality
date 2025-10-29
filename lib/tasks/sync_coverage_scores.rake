namespace :quality do
  desc "Sync coverage scores from .last_run.json files to MetricSummaries"
  task sync_coverage_scores: :environment do
    ScannedApp.where.not(status: "paused").find_each do |app|
      coverage_file = File.join(app.path, "coverage", ".last_run.json")

      if File.exist?(coverage_file)
        begin
          data = JSON.parse(File.read(coverage_file))
          coverage_pct = data.dig("result", "line")

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
          end
        rescue => e
          puts "✗ #{app.name}: Error parsing coverage - #{e.message}"
        end
      else
        puts "- #{app.name}: No coverage file found"
      end
    end

    puts "\nCoverage sync complete!"
  end
end
