class Owners::RegistrationsController < Devise::RegistrationsController
  # GET /owners/sign_up
  def new
    super
  end

  def create
    super do |owner|
      # Don't track session or set remember_me on creation
      # User needs to confirm email first
      if owner.persisted?
        # The confirmation email will be sent automatically by Devise
        # Don't sign them in or track session yet
      end
    end
  end

  # PUT /owners
  def update
    super
  end

  protected

  # This fires AFTER successful sign up
  def after_sign_up_path_for(resource)
    new_owner_session_path
  end

  def after_update_path_for(resource)
    owner_dashboard_path
  end

  private

  def track_owner_session(owner)
    cookies.permanent.encrypted[:owner_id] = owner.id
    Current.owner = owner if defined?(Current)
  end
end
