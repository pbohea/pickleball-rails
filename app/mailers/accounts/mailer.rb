# frozen_string_literal: true
class Accounts::Mailer < Devise::Mailer
  include Devise::Controllers::UrlHelpers  # gives us edit_*_password_url etc.

  default from: ENV.fetch("MAIL_FROM", "admin@pickleball.co"),
          reply_to: ENV.fetch("MAIL_FROM", "admin@pickleball.co")
  layout "mailer"
  default template_path: "accounts/mailer"  # all templates live here

  # Add this header if you're using an SES Configuration Set called "dev-logs"
  # (optional, but handy for delivery debugging)
  # before_action { headers["X-SES-CONFIGURATION-SET"] = "dev-logs" }

  def reset_password_instructions(record, token, opts = {})
    scope = Devise::Mapping.find_scope!(record) # => :user / :artist / :owner
    opts[:subject] ||= "#{brand_for(scope)} password reset"

    @reset_url = public_send("edit_#{scope}_password_url", reset_password_token: token)
    super
  end

  def confirmation_instructions(record, token, opts = {})
    scope = Devise::Mapping.find_scope!(record)
    opts[:subject] ||= "#{brand_for(scope)}: confirm your email"

    @confirmation_url = public_send("#{scope}_confirmation_url", confirmation_token: token)
    super
  end

  def unlock_instructions(record, token, opts = {})
    scope = Devise::Mapping.find_scope!(record)
    opts[:subject] ||= "#{brand_for(scope)} account unlock"

    @unlock_url = public_send("#{scope}_unlock_url", unlock_token: token)
    super
  end

  private

  def brand_for(scope)
    case scope
    when :user   then "Pickleball"
    when :artist then "Pickleball Artist"
    when :owner  then "Pickleball Owner"
    else "Pickleball"
    end
  end
end
