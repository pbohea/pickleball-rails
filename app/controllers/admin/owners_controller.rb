# app/controllers/admin/owners_controller.rb
class Admin::OwnersController < ApplicationController
  before_action :require_admin!

  def lookup
    q = params[:q].to_s.strip
    owners = if q.blank?
      Owner.none
    else
      Owner.where("username ILIKE :q OR email ILIKE :q", q: "%#{q}%")
           .order(:username).limit(20)
    end

    render json: owners.map { |o|
      { id: o.id, label: "#{o.username} (#{o.email})" }
    }
  end

  private

  def require_admin!
    unless is_admin?
      head :forbidden
    end
  end

  def is_admin?
    return false unless user_signed_in?
    admin_emails = ENV.fetch('ADMIN_EMAILS', 'admin@pickleball.co').split(',').map(&:strip)
    admin_emails.include?(current_user.email)
  end
end
