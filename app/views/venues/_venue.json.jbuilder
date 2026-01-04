json.extract! venue, :id, :address, :category, :events_count, :name, :website, :owner_id, :created_at, :updated_at
json.url venue_url(venue, format: :json)
