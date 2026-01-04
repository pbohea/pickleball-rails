class Users::SessionsController < Devise::SessionsController
  # before_action :configure_sign_in_params, only: [:create]

  def create
    super do |user|
      track_user_session(user)
    end
  end

  def destroy
    cookies.delete(:user_id)
    super
  end

  protected

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    if turbo_native_app?
      # iOS app
      menu_path
    else
      # Web browser
      new_user_session_path
    end
  end

  def respond_to_on_destroy
    # Force a proper HTML redirect instead of turbo_stream
    redirect_to after_sign_out_path_for(resource_name), status: :see_other
  end

  private

  def track_user_session(user)
    cookies.permanent.encrypted[:user_id] = user.id
    Current.user = user if defined?(Current)
  end
end
