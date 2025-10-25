# frozen_string_literal: true
# config/deploy.rb
set :application, 'code_quality'
set :repo_url, 'git@github.com:zrandles/code_quality.git'
set :branch, 'main'
set :deploy_to, "/home/zac/#{fetch(:application)}"
set :keep_releases, 5
# SSH and Git settings
set :ssh_options, {
  keys: ["#{ENV['HOME']}/.ssh/id_rsa"],
  forward_agent: true,
  auth_methods: %w[publickey],
  shell: '/bin/bash -l'
}
set :git_ssh_command, "ssh -i #{fetch(:ssh_options)[:keys].first}"
# Ruby and environment settings
set :default_shell, '/bin/bash -l -c'
set :rbenv_type, :user
set :rbenv_ruby, File.read('.ruby-version').strip
set :rbenv_prefix,
    "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w[rake gem bundle ruby rails]
set :bundle_binstubs, nil
# Puma settings
set :puma_threads,    [4, 16]
set :puma_workers,    0
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true
set :puma_systemctl_user, :system
set :puma_systemctl_bin, 'sudo systemctl'
set :puma_conf, -> { "#{current_path}/config/puma/production.rb" }
Rake::Task['puma:restart'].clear_actions
# Linked files and directories
set :linked_files, %w[config/database.yml config/master.key]
set :linked_dirs, %w[log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system public/uploads node_modules public/assets storage]
# Environment settings
set :default_env, {
  'RAILS_ENV' => 'production',
  'RACK_ENV' => 'production'
}

set :assets_prefix, 'assets'

set :assets_roles, [:web, :app]
set :keep_assets, 2

namespace :deploy do
  desc 'Run tests before deploying'
  task :run_tests do
    on roles(:app) do
      within release_path do
        with rails_env: :test do
          info "Running test suite before deployment..."
          execute :bundle, 'exec', 'rspec', '--format', 'progress'
        end
      end
    end
  end

  desc 'Restart Puma server'
  task :restart_puma_sudo do
    on roles(:app) do
      execute :sudo, :systemctl, :restart, 'code_quality.service'
    end
  end
  desc 'Generate binstubs'
  task :generate_binstubs do
    on roles(:app) do
      within release_path do
        execute :bundle, 'binstubs bundler --force'
        execute :bundle, 'binstubs puma --force'
        execute :bundle, 'binstubs rails --force'
      end
    end
  end

  desc 'Run database migrations'
  task :run_migrations do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:migrate'
        end
      end
    end
  end

  namespace :assets do
    desc 'Disable default assets backup'
    task :backup_manifest do
      # Do nothing
    end

    desc 'Build Tailwind CSS'
    task :build_tailwind do
      on roles(:web) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :bundle, 'exec', 'rails', 'tailwindcss:build'
          end
        end
      end
    end

    desc 'Precompile assets using Propshaft'
    task :precompile do
      on roles(:web) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :bundle, 'exec', 'rails', 'assets:precompile'
          end
        end
      end
    end

    desc 'Remove compiled assets'
    task :cleanup do
      on roles(:web) do
        within release_path do
          with rails_env: fetch(:rails_env) do
            execute :bundle, 'exec', 'rails', 'assets:clean'
          end
        end
      end
    end
  end

  namespace :symlink do
    Rake::Task['deploy:symlink:release'].clear_actions
    task :release do
      on release_roles(:all) do
        within deploy_to do
          # First remove existing current directory if it exists
          execute :rm, '-rf', 'current'
          # Then create the symlink directly to the release
          execute :ln, '-s', release_path, current_path
        end
      end
    end
  end

  namespace :check do
    before :linked_files, :setup_config do
      on roles(:app) do
        execute :mkdir, "-p", shared_path.join("public")
        execute :mkdir, "-p", shared_path.join("public/assets")
        execute :mkdir, "-p", release_path.join("public/assets")
      end
    end
  end
end
# Hooks
# NOTE: Do NOT clear deploy:assets:precompile or asset compilation will be disabled!
# The custom asset tasks defined above in namespace :deploy will run correctly.

# Run tests before deploying (comment out if tests are failing)
before 'deploy:updated', 'deploy:run_tests'

after 'bundler:install', 'deploy:generate_binstubs'
before 'deploy:assets:precompile', 'deploy:assets:build_tailwind'
before 'deploy:publishing', 'deploy:assets:precompile'
after 'deploy:publishing', 'deploy:restart'
after 'deploy:publishing', 'deploy:restart_puma_sudo'
after 'deploy:publishing', 'deploy:run_migrations'
after 'deploy:published', 'deploy:assets:cleanup'