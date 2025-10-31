namespace :quality do
  desc "Remove decommissioned apps and apps that no longer exist"
  task cleanup_decommissioned: :environment do
    puts "Cleaning up decommissioned apps and apps that no longer exist..."
    decommissioned_count = 0
    missing_count = 0

    ScannedApp.find_each do |app|
      # Check if path exists
      unless File.exist?(app.path)
        puts "  Removing (path not found): #{app.name} (#{app.path})"
        app.destroy
        missing_count += 1
        next
      end

      # Check if decommissioned
      if ScannedApp.decommissioned?(app.path)
        puts "  Removing (decommissioned): #{app.name} (#{app.path})"
        app.destroy
        decommissioned_count += 1
      end
    end

    puts "\nRemoved #{decommissioned_count} decommissioned apps"
    puts "Removed #{missing_count} apps with missing paths"
    puts "Remaining apps: #{ScannedApp.count}"
  end

  desc "Discover Rails apps in the ecosystem"
  task discover_apps: :environment do
    base_path = ENV['APPS_PATH'] || '/home/zac'

    puts "Discovering Rails apps in: #{base_path}"

    unless Dir.exist?(base_path)
      puts "Directory not found: #{base_path}"
      next
    end

    discovered_count = 0

    Dir.entries(base_path).sort.each do |entry|
      next if entry.start_with?('.')

      app_dir = File.join(base_path, entry)
      next unless File.directory?(app_dir)

      # Check for Capistrano-deployed app (has /current/config/application.rb)
      current_path = File.join(app_dir, 'current')
      app_path = if File.exist?(File.join(current_path, 'config', 'application.rb'))
        current_path
      elsif File.exist?(File.join(app_dir, 'config', 'application.rb'))
        app_dir
      else
        nil
      end

      if app_path
        # Skip decommissioned apps
        if ScannedApp.decommissioned?(app_path)
          puts "⊘ #{entry} (decommissioned - skipping)"
          next
        end

        app = ScannedApp.find_or_initialize_by(name: entry)
        app.path = app_path
        app.status ||= 'active'

        if app.save
          discovered_count += 1
          puts "✓ #{entry} (#{File.basename(app_path) == 'current' ? 'deployed' : 'local'})"
        else
          puts "✗ #{entry}: #{app.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "\nDiscovered #{discovered_count} Rails apps"
    puts "Total apps in database: #{ScannedApp.count}"
  end

  desc "Run all quality scans on all active apps"
  task scan_all: :environment do
    ScannedApp.where.not(status: 'paused').find_each do |app|
      puts "\n" + "="*50
      puts "Scanning: #{app.name}"
      puts "="*50

      begin
        QualityRunner.new(app).scan_all
        puts "✓ #{app.name} scanned successfully"
      rescue => e
        puts "✗ #{app.name} failed: #{e.message}"
      end
    end

    # Sync coverage scores after all scans
    puts "\n" + "="*50
    puts "Syncing coverage scores..."
    puts "="*50
    Rake::Task['quality:sync_coverage_scores'].invoke

    puts "\n✅ All scans complete!"
  end
end
