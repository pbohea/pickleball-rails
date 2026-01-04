class ApplicationController < ActionController::Base
  # Modern browser enforcement (optional)
  allow_browser versions: :modern
  
  # Add cache control for authentication-sensitive pages
  before_action :set_cache_headers_for_auth_pages
  before_action :store_user_location!, if: :storable_location?

  private

  def set_cache_headers_for_auth_pages
    # Always prevent caching for menu page and authentication-related pages
    if should_prevent_caching?
      response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate, private'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = '0'
      response.headers['Last-Modified'] = Time.current.httpdate
      response.headers['Vary'] = 'Accept-Encoding'
    end
  end

  def should_prevent_caching?
    # Prevent caching if user is authenticated OR if on menu/auth pages
    user_signed_in? ||
    controller_name.include?('sessions') ||
    controller_name.include?('registrations')
  end

  def storable_location?
    request.get? &&
      is_navigational_format? &&
      !devise_controller? &&
      !request.xhr?
  end

  def store_user_location!
    store_location_for(:user, request.fullpath)
  end

  # Devise helper access
  include Devise::Controllers::Helpers

  helper_method :user_signed_in?, :current_user

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    case resource_class.name
    when "User"
      devise_parameter_sanitizer.permit(:sign_up, keys: [])
      devise_parameter_sanitizer.permit(:account_update, keys: [])
    end
  end
end
