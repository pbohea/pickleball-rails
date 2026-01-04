module ApplicationHelper
  def is_admin?
    return false unless user_signed_in?
    admin_emails = ENV.fetch('ADMIN_EMAILS', 'admin@pickleball.co').split(',').map(&:strip)
    admin_emails.include?(current_user.email)
  end

  def can_modify_venue?(venue)
    return false unless venue
    
    # Owner of the venue can modify
    if owner_signed_in? && current_owner.venues.include?(venue)
      return true
    end
    
    # Admin access
    if is_admin?
      return true
    end
    
    false
  end




  def can_modify_event?(event)
    return false unless event

    # Artist who is performing can modify
    if artist_signed_in? && current_artist == event.artist
      return true
    end

    # Owner of the venue can modify
    if owner_signed_in? && current_owner.venues.include?(event.venue)
      return true
    end

    if promoter_signed_in? && current_promoter.id == event.promoter_id
      return true
    end

    # Admin access
    if is_admin?
      return true
    end

    false
  end

  def status_color(status)
    case status.to_s
    when "pending"
      "warning"
    when "approved"
      "success"
    when "rejected"
      "danger"
    when "duplicate"
      "secondary"
    else
      "secondary"
    end
  end

  def is_admin_email?(email)
    admin_emails = ENV.fetch('ADMIN_EMAILS', 'admin@pickleball.co').split(',').map(&:strip)
    admin_emails.include?(email)
  end
end
