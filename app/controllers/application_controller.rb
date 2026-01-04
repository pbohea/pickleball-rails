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
    artist_signed_in? || 
    owner_signed_in? ||
    promoter_signed_in? ||
    controller_name == 'pages' && action_name == 'menu' ||
    controller_name.include?('sessions') ||
    controller_name.include?('registrations') ||
    request.path.include?('/menu')
  end

  def storable_location?
    request.get? &&
      is_navigational_format? &&
      !devise_controller? &&
      !request.xhr?
  end

  def store_user_location!
    store_location_for(:user, request.fullpath)
    store_location_for(:owner, request.fullpath)
    store_location_for(:artist, request.fullpath)
    store_location_for(:promoter, request.fullpath)  

  end

  # Devise helper access
  include Devise::Controllers::Helpers

  # Make Devise-like helpers available for Owner and Artist
  helper_method :owner_signed_in?, :current_owner,
                :artist_signed_in?, :current_artist,
                :user_signed_in?, :current_user,
                :promoter_signed_in?, :current_promoter

  def current_owner
    @current_owner ||= warden.authenticate(scope: :owner)
  end

  def owner_signed_in?
    current_owner.present?
  end

  def current_artist
    @current_artist ||= warden.authenticate(scope: :artist)
  end

  def artist_signed_in?
    current_artist.present?
  end

  def current_promoter
    @current_promoter ||= warden.authenticate(scope: :promoter)
  end

  def promoter_signed_in?
    current_promoter.present?
  end

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    case resource_class.name
    when "Artist"
      devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :genre, :type, :website, :image])
      devise_parameter_sanitizer.permit(:account_update, keys: [:username, :genre, :type, :website, :image])
    when "Owner"
      devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
      devise_parameter_sanitizer.permit(:account_update, keys: [:username])
    when "User"
      devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
      devise_parameter_sanitizer.permit(:account_update, keys: [:username])
    when "Promoter"
      devise_parameter_sanitizer.permit(:sign_up,        keys: [:name, :organization])
      devise_parameter_sanitizer.permit(:account_update, keys: [:name, :organization])
    end
  end
end
