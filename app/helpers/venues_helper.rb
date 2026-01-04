module VenuesHelper
  def formatted_address(venue)
    venue.full_address.presence || "Address not available"
  end
end
