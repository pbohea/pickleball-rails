class Artists::SessionsController < Devise::SessionsController
  def create
    super do |artist|
      track_artist_session(artist)
    end
  end

  def destroy
    cookies.delete(:artist_id)
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
      new_artist_session_path
    end
  end

  def respond_to_on_destroy
    # Force a proper HTML redirect instead of turbo_stream
    redirect_to after_sign_out_path_for(resource_name), status: :see_other
  end

  private

  def track_artist_session(artist)
    cookies.permanent.encrypted[:artist_id] = artist.id
    Current.artist = artist if defined?(Current)
  end
end
