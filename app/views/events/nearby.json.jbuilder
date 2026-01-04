# Return events with search metadata
json.events @events do |event|
  json.id event.id
  json.date event.date.iso8601
  json.start_time event.start_time.iso8601
  
  if event.end_time.present?
    json.end_time event.end_time.iso8601
  else
    json.end_time nil
  end
  
  json.description event.description
  json.cover event.cover
  json.cover_amount event.cover_amount
  json.category event.category
  json.indoors event.indoors

  json.venue do
    json.id event.venue.id
    json.name event.venue.name
    json.category event.venue.category
    
    json.coordinate do
      json.latitude event.venue.latitude&.to_f || 0.0
      json.longitude event.venue.longitude&.to_f || 0.0
    end
    
    json.website event.venue.website
    
    # Add distance if we have search coordinates
    if @search_params[:has_location] && @search_params[:lat] && @search_params[:lng]
      distance = Geocoder::Calculations.distance_between(
        [@search_params[:lat], @search_params[:lng]], 
        [event.venue.latitude, event.venue.longitude]
      )
      json.distance_miles distance.round(1)
    end
  end

  json.artist do
    json.id event.artist.id
    json.username event.artist.username
    
    if event.artist.image.attached?
      json.image_url rails_blob_url(event.artist.image)
    else
      json.image_url nil
    end
    
    begin
      json.profile_url artist_url(event.artist)
    rescue => e
      Rails.logger.warn "Failed to generate artist URL for artist #{event.artist.id}: #{e.message}"
      json.profile_url nil
    end
  end
end

# Include search parameters for the client
json.search do
  json.address @search_params[:address]
  json.latitude @search_params[:lat]
  json.longitude @search_params[:lng]
  json.radius @search_params[:radius]
  json.has_location @search_params[:has_location]
  json.total_results @events.count
end
