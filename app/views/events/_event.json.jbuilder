# Keep all the original attributes for backward compatibility
json.extract! event, :id, :category, :cover, :cover_amount, :date, :description,
                    :start_time, :end_time, :indoors, :artist_id,
                    :venue_id, :created_at, :updated_at
json.url event_url(event, format: :json)

# ---- Time zone aware additions (for map/UI) ----
tz = event.venue&.time_zone.presence || Time.zone.name
start_local = event.start_time.in_time_zone(tz)
end_local   = event.end_time&.in_time_zone(tz)

json.venue_tz           tz
json.date_local         start_local.to_date.iso8601
json.start_time_local   start_local.iso8601
json.end_time_local     (end_local&.iso8601)

# Handy display strings (optional for clients)
json.date_display       start_local.strftime("%A, %b %-d")
json.start_time_display start_local.strftime("%-I:%M %p")
json.end_time_display   (end_local&.strftime("%-I:%M %p"))

# (Optional) echo minimal venue tz on nested venue if your caller builds it here:
# json.venue do
#   json.time_zone tz
# end
