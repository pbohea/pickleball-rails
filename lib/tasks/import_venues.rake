# lib/tasks/import_venues.rake
# Run with: bin/rails venues:import
namespace :venues do
  desc "Import venues from combined_venues_tz.json"
  task import: :environment do
    file_path = Rails.root.join("db", "venue_imports", "combined_venues_tz.json")

    unless File.exist?(file_path)
      puts "❌ File not found: #{file_path}"
      next
    end

    puts "📄 Importing from #{file_path}"
    file = File.read(file_path)
    data = JSON.parse(file)

    data.each do |venue_json|
      # Skip if place_id is already in DB
      if Venue.exists?(place_id: venue_json["place_id"])
        puts "⏩ Skipping existing venue: #{venue_json["name"]}"
        next
      end

      venue = Venue.new(
        name:           venue_json["name"],
        street_address: venue_json["street_address"],
        city:           venue_json["city"],
        state:          venue_json["state"],
        zip_code:       venue_json["zip_code"],
        latitude:       venue_json["latitude"],
        longitude:      venue_json["longitude"],
        website:        venue_json["website"],
        category:       venue_json["category"],
        place_id:       venue_json["place_id"],
        time_zone:      venue_json["time_zone"],
        skip_geocoding: true
      )

      if venue.save
        puts "✅ Created venue: #{venue.name}"
      else
        puts "❌ Failed to save #{venue.name}: #{venue.errors.full_messages.join(', ')}"
      end
    end
  end
end
