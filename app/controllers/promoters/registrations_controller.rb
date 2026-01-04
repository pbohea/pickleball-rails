class Promoters::RegistrationsController < Devise::RegistrationsController
  # GET /promoters/sign_up
  def new
    super
  end

  def create
    super do |promoter|
      # Don't track session or set remember_me on creation
      # User needs to confirm email first
      if promoter.persisted?
        # The confirmation email will be sent automatically by Devise
        # Don't sign them in or track session yet
      end
    end
  end

  # PUT /promoters
  def update
    super
  end

  protected

  # This fires AFTER successful sign up
  def after_sign_up_path_for(resource)
    new_promoter_session_path
  end

  def after_update_path_for(resource)
    promoter_dashboard_path
  end

  private

  def track_promoter_session(promoter)
    cookies.permanent.encrypted[:promoter_id] = promoter.id
    Current.promoter = promoter if defined?(Current)
  end
end
