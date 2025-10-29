namespace :quality do
  desc "Discover Rails apps in the ecosystem"
  task discover_apps: :environment do
    base_path = ENV['APPS_PATH'] || '/home/zac/zac_ecosystem/apps'

    puts "Discovering Rails apps in: #{base_path}"

    unless Dir.exist?(base_path)
      puts "Directory not found: #{base_path}"
      next
    end

    discovered_count = 0

    Dir.entries(base_path).sort.each do |entry|
      next if entry.start_with?('.')

      app_path = File.join(base_path, entry)
      next unless File.directory?(app_path)

      # Check if it's a Rails app
      if File.exist?(File.join(app_path, 'config', 'application.rb'))
        app = ScannedApp.find_or_initialize_by(name: entry)
        app.path = app_path
        app.status ||= 'active'

        if app.save
          discovered_count += 1
          puts "✓ #{entry}"
        else
          puts "✗ #{entry}: #{app.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "\nDiscovered #{discovered_count} Rails apps"
    puts "Total apps in database: #{ScannedApp.count}"
  end
end
