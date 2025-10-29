namespace :quality do
  desc "Scan all apps for quality metrics"
  task scan_all: :environment do
    puts "Starting quality scans for all apps..."

    # Determine base path based on environment
    base_path = if Rails.env.production?
      "/home/zac"
    else
      File.expand_path("~/zac_ecosystem/apps")
    end

    # Apps to scan (excluding triplechain)
    app_names = %w[
      agent_tracker
      app_monitor
      chromatic
      code_quality
      custom_pages
      golden_deployment
      high_score_basketball
      idea_tracker
      niche_digest
      nike_giveaway
      powered_cube
      shopify_stockout_calc
      soccer_elo
      solitaire
      test_dummy_app
      test_game_template
      trivia_app
      wordle_app
      wordle_variant
    ]

    scanned_count = 0
    failed_count = 0

    app_names.each do |app_name|
      app_path = if Rails.env.production?
        File.join(base_path, app_name, "current")
      else
        File.join(base_path, app_name)
      end

      # Skip if app directory doesn't exist
      unless Dir.exist?(app_path)
        puts "⚠️  Skipping #{app_name} - directory not found: #{app_path}"
        next
      end

      puts "\n📊 Scanning #{app_name}..."

      # Find or create ScannedApp record
      app = ScannedApp.find_or_create_by!(name: app_name) do |a|
        a.path = app_path
        a.status = "pending"
      end

      # Update path in case it changed
      app.update!(path: app_path)

      begin
        # Run all scanners synchronously
        puts "  🔒 Running security scan (Brakeman)..."
        SecurityScanner.new(app).scan

        puts "  📈 Running static analysis (Reek, Flog, Flay)..."
        StaticAnalysisScanner.new(app).scan

        puts "  👮 Running RuboCop (high-value cops only)..."
        RubocopScanner.new(app).scan

        puts "  🎯 Running drift detection..."
        DriftScanner.new(app).scan

        puts "  🧪 Running test coverage scan..."
        begin
          Timeout.timeout(120) do # 2 minute timeout per app
            TestCoverageScanner.new(app).scan
          end
        rescue Timeout::Error
          puts "     ⚠️  Test coverage scan timed out (skipping)"
        rescue => coverage_error
          puts "     ⚠️  Test coverage scan failed: #{coverage_error.message}"
        end

        # Update app status based on scan results
        critical_count = app.quality_scans.where(severity: ["critical", "high"]).count
        medium_count = app.quality_scans.where(severity: "medium").count

        status = if critical_count > 0
          "critical"
        elsif medium_count > 5
          "warning"
        else
          "healthy"
        end

        app.update!(
          last_scanned_at: Time.current,
          status: status
        )

        puts "  ✅ Scan completed: #{status.upcase} (#{critical_count} critical, #{medium_count} medium issues)"
        scanned_count += 1
      rescue => e
        puts "  ❌ Scan failed: #{e.message}"
        puts "     #{e.backtrace.first(3).join("\n     ")}"
        failed_count += 1

        # Mark app as failed
        app.update!(
          status: "error",
          last_scanned_at: Time.current
        )
      end
    end

    puts "\n" + "=" * 60
    puts "✅ Quality scan completed!"
    puts "   Apps scanned: #{scanned_count}"
    puts "   Apps failed: #{failed_count}"
    puts "   Total apps: #{scanned_count + failed_count}"
    puts "=" * 60
  end

  desc "Scan a specific app"
  task :scan_app, [:app_name] => :environment do |t, args|
    app_name = args[:app_name]

    unless app_name
      puts "❌ Usage: rake quality:scan_app[app_name]"
      exit 1
    end

    # Determine base path based on environment
    base_path = if Rails.env.production?
      "/home/zac"
    else
      File.expand_path("~/zac_ecosystem/apps")
    end

    app_path = if Rails.env.production?
      File.join(base_path, app_name, "current")
    else
      File.join(base_path, app_name)
    end

    unless Dir.exist?(app_path)
      puts "❌ App directory not found: #{app_path}"
      exit 1
    end

    puts "📊 Scanning #{app_name}..."

    # Find or create ScannedApp record
    app = ScannedApp.find_or_create_by!(name: app_name) do |a|
      a.path = app_path
      a.status = "pending"
    end

    # Update path in case it changed
    app.update!(path: app_path)

    # Run all scanners
    puts "  🔒 Running security scan..."
    SecurityScanner.new(app).scan

    puts "  📈 Running static analysis..."
    StaticAnalysisScanner.new(app).scan

    puts "  👮 Running RuboCop..."
    RubocopScanner.new(app).scan

    puts "  🎯 Running drift detection..."
    DriftScanner.new(app).scan

    puts "  🧪 Running test coverage scan..."
    begin
      Timeout.timeout(120) do # 2 minute timeout
        TestCoverageScanner.new(app).scan
      end
    rescue Timeout::Error
      puts "     ⚠️  Test coverage scan timed out (skipping)"
    rescue => coverage_error
      puts "     ⚠️  Test coverage scan failed: #{coverage_error.message}"
    end

    # Update app status
    critical_count = app.quality_scans.where(severity: ["critical", "high"]).count
    medium_count = app.quality_scans.where(severity: "medium").count

    status = if critical_count > 0
      "critical"
    elsif medium_count > 5
      "warning"
    else
      "healthy"
    end

    app.update!(
      last_scanned_at: Time.current,
      status: status
    )

    puts "✅ Scan completed: #{status.upcase}"
    puts "   Critical/High: #{critical_count}"
    puts "   Medium: #{medium_count}"
  end

  desc "Clear all scan data"
  task clear_scans: :environment do
    puts "⚠️  Clearing all scan data..."

    QualityScan.delete_all
    MetricSummary.delete_all
    ScanRun.delete_all
    ScannedApp.update_all(last_scanned_at: nil, status: nil)

    puts "✅ All scan data cleared"
  end
end
