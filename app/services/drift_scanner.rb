class DriftScanner
  include ScannerBase

  CRITICAL_FILES = [
    "config/deploy.rb",
    "config/deploy/production.rb",
    "config/environments/production.rb",
    "config/routes.rb",
    "Gemfile"
  ].freeze

  GOLDEN_PATH = File.expand_path("~/zac_ecosystem/apps/golden_deployment")

  def scan
    return unless app_exists?
    return if app.name == "golden_deployment" # Skip golden itself

    check_deployment_config
    check_gem_versions
    check_tailwind_setup
    check_path_based_routing
    save_results
  end

  private

  def scan_type
    "drift"
  end

  def check_deployment_config
    # Check if deploy.rb exists and is configured correctly
    deploy_file = File.join(app.path, "config", "deploy.rb")

    unless File.exist?(deploy_file)
      @results << {
        scan_type: "drift",
        severity: "critical",
        message: "Missing config/deploy.rb - deployment not configured",
        file_path: "config/deploy.rb",
        scanned_at: Time.current
      }
      return
    end

    # Check for critical deployment settings
    deploy_content = File.read(deploy_file)

    unless deploy_content.include?("set :application")
      @results << {
        scan_type: "drift",
        severity: "high",
        message: "Deployment config missing :application setting",
        file_path: "config/deploy.rb",
        scanned_at: Time.current
      }
    end
  rescue StandardError => error
    Rails.logger.error("Drift check failed for #{app.name}: #{error.message}")
  end

  def check_gem_versions
    # Compare Gemfile.lock versions for critical gems
    app_gemfile_lock = File.join(app.path, "Gemfile.lock")
    golden_gemfile_lock = File.join(GOLDEN_PATH, "Gemfile.lock")

    return unless File.exist?(app_gemfile_lock) && File.exist?(golden_gemfile_lock)

    app_gems = parse_gemfile_lock(app_gemfile_lock)
    golden_gems = parse_gemfile_lock(golden_gemfile_lock)

    # Check Rails version
    if app_gems["rails"] && golden_gems["rails"]
      if app_gems["rails"] != golden_gems["rails"]
        @results << {
          scan_type: "drift",
          severity: "medium",
          message: "Rails version (#{app_gems['rails']}) differs from golden_deployment (#{golden_gems['rails']})",
          file_path: "Gemfile.lock",
          scanned_at: Time.current
        }
      end
    end
  rescue StandardError => error
    Rails.logger.error("Gem version check failed for #{app.name}: #{error.message}")
  end

  def parse_gemfile_lock(file_path)
    content = File.read(file_path)
    gems = {}

    content.scan(/^\s{4}(\w+)\s+\(([^)]+)\)/) do |name, version|
      gems[name] = version
    end

    gems
  end

  def check_tailwind_setup
    # Check if Tailwind is properly configured
    production_rb = File.join(app.path, "config", "environments", "production.rb")

    return unless File.exist?(production_rb)

    content = File.read(production_rb)

    unless content.include?("tailwindcss:build")
      @results << {
        scan_type: "drift",
        severity: "medium",
        message: "Tailwind CSS build task may not be configured for deployment",
        file_path: "config/environments/production.rb",
        scanned_at: Time.current
      }
    end
  rescue StandardError => error
    Rails.logger.error("Tailwind check failed for #{app.name}: #{error.message}")
  end

  def check_path_based_routing
    # Check if path-based routing is configured
    production_rb = File.join(app.path, "config", "environments", "production.rb")

    return unless File.exist?(production_rb)

    content = File.read(production_rb)

    unless content.include?("relative_url_root")
      @results << {
        scan_type: "drift",
        severity: "high",
        message: "Path-based routing (relative_url_root) not configured - app may not work in production",
        file_path: "config/environments/production.rb",
        scanned_at: Time.current
      }
    end
  rescue StandardError => error
    Rails.logger.error("Path-based routing check failed for #{app.name}: #{error.message}")
  end

  # save_results and create_summary are now provided by ScannerBase
end
