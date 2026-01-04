# Create the main response object
json.events @events do |event|
  # ---- Existing fields (kept as-is) ----
  json.id          event.id
  json.date        event.date.iso8601
  json.start_time  event.start_time.iso8601
  json.end_time    (event.end_time.present? ? event.end_time.iso8601 : nil)
  json.description event.description
  json.cover       event.cover
  json.cover_amount event.cover_amount
  json.category    event.category
  json.indoors     event.indoors

  # ---- Time zone aware additions for the map ----
  tz = event.venue&.time_zone.presence || Time.zone.name
  start_local = event.start_time.in_time_zone(tz)
  end_local   = event.end_time&.in_time_zone(tz)

  json.venue_tz tz
  json.date_local start_local.to_date.iso8601
  json.start_time_local start_local.iso8601 # e.g. "2025-08-26T11:30:00-05:00"
  json.end_time_local   (end_local&.iso8601)

  # Optional display helpers (nice for callouts/pin subtitles)
  json.start_time_display start_local.strftime("%-I:%M %p")           # "11:30 AM"
  json.end_time_display   (end_local&.strftime("%-I:%M %p"))          # "12:30 PM"
  json.date_display       start_local.strftime("%A, %b %-d")          # "Tuesday, Aug 26"

  # ---- Venue ----
  json.venue do
    json.id       event.venue.id
    json.slug     event.venue.slug
    json.name     event.venue.name
    json.category event.venue.category
    json.city     event.venue.city
    json.time_zone (event.venue.time_zone)    # echo TZ on venue too, handy for clients

    # iOS coordinate object
    json.coordinate do
      json.latitude  (event.venue.latitude&.to_f || 0.0)
      json.longitude (event.venue.longitude&.to_f || 0.0)
    end

    json.website event.venue.website
  end

  # ---- Artist ----
  json.artist do
    if event.artist.present?
      json.id            event.artist.id
      json.slug          event.artist.slug
      json.username      event.artist.username
      json.is_database_artist true

      if event.artist.image.attached?
        json.image_url rails_blob_url(event.artist.image)
      else
        json.image_url nil
      end

      begin
        json.profile_url artist_url(event.artist)
      rescue => e
        Rails.logger.warn "Failed to generate artist URL for artist #{event.artist_id}: #{e.message}"
        json.profile_url nil
      end
    else
      json.id nil
      json.username event.artist_name
      json.is_database_artist false
      json.image_url nil
      json.profile_url nil
    end
  end
end

# Optional center for map
if @center_lat && @center_lng
  json.center do
    json.latitude  @center_lat
    json.longitude @center_lng
  end
else
  json.center nil
end

# Selected venue (if any)
json.selected_venue_id @selected_venue_id
