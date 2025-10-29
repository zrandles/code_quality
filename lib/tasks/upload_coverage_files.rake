namespace :quality do
  desc "Upload local coverage files to production for all apps"
  task :upload_coverage_files => :environment do
    require 'net/scp'

    host = '24.199.71.69'
    user = 'zac'

    ScannedApp.where.not(status: 'paused').find_each do |app|
      local_last_run = File.join(ENV['HOME'], 'zac_ecosystem', 'apps', app.name, 'coverage', '.last_run.json')
      local_resultset = File.join(ENV['HOME'], 'zac_ecosystem', 'apps', app.name, 'coverage', '.resultset.json')

      # Try to upload .last_run.json first (preferred format)
      uploaded = false

      if File.exist?(local_last_run)
        remote_path = "/home/zac/#{app.name}/current/coverage/.last_run.json"
        begin
          system("ssh #{user}@#{host} 'mkdir -p /home/zac/#{app.name}/current/coverage'")
          system("scp #{local_last_run} #{user}@#{host}:#{remote_path}")
          puts "✓ #{app.name}: Uploaded .last_run.json"
          uploaded = true
        rescue => e
          puts "✗ #{app.name}: Failed to upload .last_run.json - #{e.message}"
        end
      elsif File.exist?(local_resultset)
        # Upload .resultset.json as fallback
        remote_path = "/home/zac/#{app.name}/current/coverage/.resultset.json"
        begin
          system("ssh #{user}@#{host} 'mkdir -p /home/zac/#{app.name}/current/coverage'")
          system("scp #{local_resultset} #{user}@#{host}:#{remote_path}")
          puts "✓ #{app.name}: Uploaded .resultset.json"
          uploaded = true
        rescue => e
          puts "✗ #{app.name}: Failed to upload .resultset.json - #{e.message}"
        end
      end

      puts "- #{app.name}: No local coverage file found" unless uploaded
    end

    puts "\nDone! Run 'rake quality:sync_coverage_scores' on production to update dashboard."
  end
end
