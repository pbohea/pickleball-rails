# config/environments/production.rb
require "active_support/core_ext/integer/time"

Rails.application.configure do
  # --- Core perf/safety ---
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # If you later add a CDN or S3 for assets, we can set config.asset_host.
  # config.asset_host = "https://assets.pickleball.co"

  # Store uploaded files on S3 in production
  config.active_storage.service = :amazon

  # SSL behind Lightsail/Load Balancer or Nginx
  config.assume_ssl = true
  config.force_ssl  = true
  # Optionally skip redirect for health checks:
  # config.ssl_options = { redirect: { exclude: ->(req) { req.path == "/up" } } }

  # --- Logging ---
  config.log_tags = [:request_id]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  # --- Caching / Jobs ---
  config.cache_store = :solid_cache_store
  config.active_job.queue_adapter = :solid_queue

  # --- Mailer (Amazon SES SMTP, like your dev setup) ---
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address:              ENV.fetch("SES_SMTP_HOST"),
    port:                 587,
    user_name:            ENV.fetch("SES_SMTP_USERNAME"),
    password:             ENV.fetch("SES_SMTP_PASSWORD"),
    authentication:       :login,
    enable_starttls_auto: true
  }
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "pickleball.co"),
    protocol: "https"
  }

  # --- I18n / DB ---
  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]

  # --- Host header protection ---
  config.hosts = [
    ENV.fetch("APP_HOST", "pickleball.co"),
    /.*\.pickleball\.co/
  ]
  config.host_authorization = { exclude: ->(req) { req.path == "/up" } }
end
