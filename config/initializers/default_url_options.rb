# Set canonical URL generation in production only.
if Rails.env.production?
  Rails.application.routes.default_url_options[:host] = ENV.fetch("APP_HOST", "pickleball.co")
  Rails.application.routes.default_url_options[:protocol] = "https"
end
