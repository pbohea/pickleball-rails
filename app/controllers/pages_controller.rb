class PagesController < ApplicationController
  def home
  end

  def menu
    redirect_to dashboard_path if user_signed_in?
  end

end
