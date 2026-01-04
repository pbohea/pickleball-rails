# Geocoder.configure(
#   lookup: :google,
#   api_key: ENV["GMAPS_KEY"],
#   timeout: 5,
#   units: :mi
# )

# Use OpenStreetMap's free geocoding service (no API key required)
Geocoder.configure(
  lookup: :nominatim,
  timeout: 5,
  units: :mi,
  use_https: true,
  
  # Be nice to the free service
  cache: Rails.cache,
  
  # Add a user agent (required by Nominatim)
  http_headers: {
    "User-Agent" => "Pickleball/1.0 (admin@pickleball.co)"
  }
)
