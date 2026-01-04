class VenueOwnershipMailer < ApplicationMailer
  # New owner got assigned (first assignment or reassignment)
  def assigned_to_new_owner(venue:, new_owner:, old_owner: nil)
    @venue     = venue
    @owner     = new_owner # match your template style (uses @owner)
    @old_owner = old_owner
    @venue_url = venue_url(@venue)

    return unless @owner&.email.present?

    mail(
      to: @owner.email,
      subject: "You’ve been assigned as the owner of #{@venue.name}"
    )
  end

  # Old owner lost ownership due to reassignment to someone else
  def reassigned_from_old_owner(venue:, old_owner:, new_owner:)
    @venue     = venue
    @owner     = old_owner
    @new_owner = new_owner
    @venue_url = venue_url(@venue)

    return unless @owner&.email.present?

    mail(
      to: @owner.email,
      subject: "Ownership of #{@venue.name} has been reassigned"
    )
  end

  # Old owner removed; venue now has no owner
  def ownership_removed_from_owner(venue:, old_owner:)
    @venue     = venue
    @owner     = old_owner
    @venue_url = venue_url(@venue)

    return unless @owner&.email.present?

    mail(
      to: @owner.email,
      subject: "You are no longer the owner of #{@venue.name}"
    )
  end
end
