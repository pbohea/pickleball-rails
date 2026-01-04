# config/puma.rb

# Threads: match DB pool later; start small
max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", 5))
threads max_threads, max_threads

# Optional multi-process (start with 1 on a 2 vCPU box)
workers Integer(ENV.fetch("WEB_CONCURRENCY", 1))

# Environment
environment ENV.fetch("RAILS_ENV", "production")

# Bind: Unix socket for Nginx (create this dir in Step 2)
app_dir = File.expand_path("../..", __FILE__)
bind "unix://#{app_dir}/tmp/sockets/puma.sock"

# PID/State files (handy for tooling)
pidfile  "#{app_dir}/tmp/pids/puma.pid"
state_path "#{app_dir}/tmp/pids/puma.state"

# Preload for copy-on-write memory savings
preload_app!

# Don’t run Solid Queue inside Puma in prod; we have a separate service
# plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Restart via `bin/rails restart`
plugin :tmp_restart

# Reconnect ActiveRecord after fork
on_worker_boot do
  require "active_record"
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
