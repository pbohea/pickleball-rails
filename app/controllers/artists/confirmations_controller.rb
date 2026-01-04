class Artists::ConfirmationsController < Devise::ConfirmationsController
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])
    yield resource if block_given?

    if resource.errors.empty?
      set_flash_message!(:notice, :confirmed)
      
      # Set remember_me on the resource BEFORE sign_in
      resource.remember_me = true
      resource.remember_me!
      
      # Sign in and explicitly pass event: :authentication to trigger remember cookie
      sign_in(resource_name, resource, event: :authentication, store: true)
      
      # Manually generate and set the remember cookie
      resource.class.serialize_into_cookie(resource).tap do |cookie_data|
        cookies.permanent.signed["remember_artist_token"] = {
          value: cookie_data,
          httponly: true,
          secure: Rails.env.production?
        }
      end
      
      track_artist_session(resource)
      
      respond_with_navigational(resource){ redirect_to after_confirmation_path_for(resource_name, resource) }
    else
      respond_with_navigational(resource.errors, status: :unprocessable_entity){ render :new }
    end
  end

  protected

  def after_confirmation_path_for(resource_name, resource)
    artist_dashboard_path
  end

  private

  def track_artist_session(artist)
    cookies.permanent.encrypted[:artist_id] = artist.id
    Current.artist = artist if defined?(Current)
  end
end
