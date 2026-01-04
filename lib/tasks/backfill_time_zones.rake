# lib/tasks/backfill_time_zones.rake
namespace :venues do
  desc "Backfill venues.time_zone using lat/lon (offline via timezone_finder)"
  task backfill_time_zones: :environment do
    require "timezone_finder"

    tf = TimezoneFinder.create

    updated = 0
    skipped_already_set = 0
    skipped_missing_coords = 0
    failed_lookup = 0
    invalid_zone = 0

    puts "Starting time zone backfill for #{Venue.count} venues..."
    Venue.find_each(batch_size: 500) do |v|
      if v.time_zone.present?
        skipped_already_set += 1
        next
      end

      lat = v.latitude
      lng = v.longitude
      unless lat && lng && lat.between?(-90, 90) && lng.between?(-180, 180)
        skipped_missing_coords += 1
        next
      end

      # Primary lookup
      tzid = tf.timezone_at(lat: lat, lng: lng)
      # Fallback: use closest polygon if exact point is on a border or polygon hole
      tzid ||= tf.closest_timezone_at(lat: lat, lng: lng)

      if tzid.nil?
        failed_lookup += 1
        next
      end

      # Ensure Rails recognizes it
      if ActiveSupport::TimeZone[tzid].nil?
        invalid_zone += 1
        next
      end

      # Avoid callbacks; just set the column
      v.update_columns(time_zone: tzid, updated_at: Time.current)
      updated += 1
    end

    remaining = Venue.where(time_zone: [nil, ""]).count
    puts <<~MSG
      ✅ Backfill complete.
      - Updated: #{updated}
      - Skipped (already set): #{skipped_already_set}
      - Skipped (missing/invalid coords): #{skipped_missing_coords}
      - Failed lookup: #{failed_lookup}
      - Invalid IANA zone (unrecognized by Rails): #{invalid_zone}
      - Remaining without time_zone: #{remaining}
    MSG
  end
end
