app_dir = "/home/zac/code_quality/current"
shared_dir = "/home/zac/code_quality/shared"

# Set up socket location
bind "unix://#{shared_dir}/tmp/sockets/puma.sock"

# Set master PID and state locations
pidfile "#{shared_dir}/tmp/pids/puma.pid"
state_path "#{shared_dir}/tmp/pids/puma.state"

# Logging
stdout_redirect "#{shared_dir}/log/puma.stdout.log", "#{shared_dir}/log/puma.stderr.log", true

# Set workers
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Preload app
preload_app!

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart

# Set the environment
environment ENV.fetch("RAILS_ENV") { "production" }

# Include any other Puma settings you need
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# If you need any hooks or additional configurations, add them here
# Solid Queue plugin disabled - start separately if needed
# plugin :solid_queue