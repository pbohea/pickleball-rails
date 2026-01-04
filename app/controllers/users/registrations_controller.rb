class Users::RegistrationsController < Devise::RegistrationsController
  # GET /users/sign_up
  def new
    super
  end

  # POST /users
def create
  super do |user|
    if user.persisted?
      user.remember_me = true
      user.save
    end
    track_user_session(user)
  end
end

  # PUT /users
  def update
    super
  end

  protected

  # def after_sign_up_path_for(resource)
  #   stored_location_for(resource) || user_dashboard_path(resource)
  # end

  def after_sign_up_path_for(resource)
    # @stored_path ||= stored_location_for(resource)
    # Rails.logger.info "=== STORED LOCATION: #{@stored_path.inspect} ==="
    # Rails.logger.info "=== USING PATH: #{@stored_path || user_dashboard_path(resource)} ==="

    # @stored_path || user_dashboard_path(resource)
    user_landing_path(resource)
  end

  def after_update_path_for(resource)
    stored_location_for(resource) || user_dashboard_path
  end

  def respond_with(resource, _opts = {})
    if action_name == "create" && resource.persisted?
      # Force a proper HTML redirect instead of turbo_stream
      redirect_to after_sign_up_path_for(resource), status: :see_other
    else
      super
    end
  end

  private

  def track_user_session(user)
    cookies.permanent.encrypted[:user_id] = user.id
    Current.user = user if defined?(Current)
  end
end
