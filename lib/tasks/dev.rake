desc "Fill the database tables with some sample data"
task sample_data: :environment do
  unless Rails.env.development?
    puts "❌ This task is only intended for development."
    next
  end

  puts "Running sample data seed in development..."

  require "faker"
  require "http"
  require "uri"
  require "open-uri"

  puts "Deleting existing records..."
  Event.destroy_all
  VenueFollow.delete_all
  VenueRequest.destroy_all
  ArtistFollow.delete_all
  NotificationToken.delete_all
  Artist.destroy_all
  User.destroy_all
  Owner.destroy_all

  # owners
  owners = [
    Owner.new(email: "owner@example.com",  password: "Password1"),
    Owner.new(email: "owner2@example.com", password: "Password1"),
  ]
  owners.each do |o|
    o.skip_confirmation! if o.respond_to?(:skip_confirmation!)
    o.save!
  end

  # users
  5.times do
    name = Faker::Name.first_name
    User.create!(email: "#{name.downcase}_user@example.com", password: "Password1")
  end

  # specific user
  User.create!(email: "admin@pickleball.co", password: "Pickleball1492!")

  puts "Creating artists..."

  # --- Artists (confirmable-safe) ---
  callback_was_skipped = false
  if Artist._validate_callbacks.any? { |cb| cb.filter == :website_https_supported }
    Artist.skip_callback(:validate, :website_https_supported)
    callback_was_skipped = true
  end

  allowed_performance_types = ["Guitar", "Piano", "Band", "DJ", "Other"]
  allowed_genres = ["Country", "Rock", "Alternative", "Jazz", "Electronic"]
  bios = [
    "Acoustic guitarist playing heartfelt covers from artists like John Mayer and The Lumineers. Always down for a crowd singalong.",
    "Indie-folk duo blending originals and soulful renditions of classic hits. Known for chill patio vibes and tight harmonies.",
    "High-energy cover band playing everything from '90s alt rock to early 2000s pop-punk. Bring your voice — we'll bring the volume.",
    "Vinyl-loving DJ spinning funky house, retro pop, and deep cuts that keep the crowd moving all night.",
    "Piano bar regular mixing Broadway favorites with classic rock singalongs. Requests welcome!",
    "Country guitarist with a modern edge. Think Morgan Wallen meets Eric Church — plus a few surprises.",
    "Loop pedal wizard layering vocals, guitar, and rhythm live. Covers, mashups, and a bit of improv.",
    "Brooklyn-based 3-piece band playing nostalgic '90s covers and alternative deep cuts. Intimate shows, loud memories.",
    "Soulful solo artist bringing smooth vocals and acoustic takes on R&B classics. Ideal for date nights and dim lighting.",
    "DJ specializing in dancefloor-filling mashups, throwbacks, and late-night energy sets. No skips.",
  ]

  artists = []
  created_count = 0
  attempts = 0
  max_attempts = 500

  begin
    while created_count < 500 && attempts < max_attempts
      attempts += 1
      name = Faker::Name.first_name
      email = "#{name.downcase}_artist@example.com"
      username = "#{name.downcase}_music" # (avoid spaces if your validation forbids them)

      next if Artist.exists?(email: email) || Artist.exists?(username: username)

      begin
        artist = Artist.new(
          email: email,
          password: "Password1",
          username: username,
          genre: allowed_genres.sample,
          performance_type: allowed_performance_types.sample,
          website: "https://www.google.com",
          bio: bios.sample,
          instagram_username: "testuser#{rand(1000..9999)}",
          tiktok_username: "testuser#{rand(1000..9999)}",
          youtube_username: "testuser#{rand(1000..9999)}",
          spotify_artist_id: SecureRandom.alphanumeric(22),
        )
        artist.skip_confirmation! if artist.respond_to?(:skip_confirmation!)
        artist.save!

        image_files = Dir.glob(Rails.root.join("db", "sample_images", "*.{jpg,jpeg,png,gif}"))
        if image_files.any?
          selected_image = image_files.sample
          filename = File.basename(selected_image)
          artist.image.attach(
            io: File.open(selected_image),
            filename: "#{name.downcase}_#{filename}",
            content_type: "image/#{File.extname(selected_image)[1..-1]}",
          )
        else
          avatar_url = "https://i.pravatar.cc/300?u=#{SecureRandom.uuid}"
          artist.image.attach(
            io: URI.open(avatar_url),
            filename: "#{name.downcase}.png",
            content_type: "image/png",
          )
        end

        artists << artist
        created_count += 1
      rescue OpenURI::HTTPError, SocketError => e
        puts "Avatar fetch failed (#{e.class}): skipping remote image."
        created_count += 1
        next
      rescue ActiveRecord::RecordInvalid => e
        puts "Skipping duplicate/invalid artist: #{e.message}"
        next
      end
    end

    puts "Created #{created_count} artists after #{attempts} attempts"

    seeded = Artist.new(
      email: "artist@example.com",
      password: "Password1",
      username: "pat_artist",
      performance_type: "Guitar",
    )
    seeded.skip_confirmation! if seeded.respond_to?(:skip_confirmation!)
    seeded.save!
  ensure
    Artist.set_callback(:validate, :website_https_supported) if callback_was_skipped
  end

  puts "Creating events..."

  cities = Venue.distinct.pluck(:city).compact

  def build_times
    random_start = Faker::Time.between(from: DateTime.now, to: DateTime.now + 2.days)
    hour = random_start.hour
    minute = (random_start.min / 15.0).round * 15
    hour += 1 and minute = 0 if minute == 60
    start_dt = random_start.change(hour: hour, min: minute, sec: 0)
    base_durations = [1.hour, 1.5.hours, 2.hours, 2.5.hours, 3.hours, 4.hours]
    long_durations = [3.hours, 4.hours, 5.hours, 6.hours]
    duration = start_dt.hour >= 22 ? long_durations.sample : base_durations.sample
    [start_dt, start_dt + duration]
  end

  event_descriptions = [
    "Join us for an intimate acoustic night featuring local talent and cold drinks.",
    "Experience a soulful evening of blues and brews at your favorite neighborhood bar.",
    "Don't miss this high-energy cover band playing your favorite hits from the '90s to today.",
    "A solo singer-songwriter takes the stage with original songs and heartfelt lyrics.",
    "Enjoy a cozy evening of jazz and cocktails in a candle-lit setting.",
    "A rotating lineup of local acts brings variety to the mic.",
    "Come catch a one-night-only performance from a rising local artist.",
    "This duo blends guitar and harmonies into a perfect mix of old-school and modern covers.",
    "Live music under the stars featuring a mix of acoustic sets and upbeat originals.",
    "A relaxed Sunday set with brunch vibes, acoustic instruments, and feel-good music.",
  ]

  artist_event_counts = Hash.new(0)
  venue_event_counts = Hash.new(0)

  cities.each do |city|
    venues_in_city = Venue.where(city: city)
    next if venues_in_city.empty?

    puts "Creating events for #{city} (#{venues_in_city.count} venues)"

    attempts = 0
    events_created = 0
    max_attempts = 100

    while events_created < 30 && attempts < max_attempts
      attempts += 1

      available_artists = artists.select { |a| artist_event_counts[a.id] < 10 }
      available_venues  = venues_in_city.select { |v| venue_event_counts[v.id] < 10 }

      if available_artists.empty? || available_venues.empty?
        puts "  Reached limit: No more available artists or venues in #{city}"
        break
      end

      selected_artist = available_artists.sample
      selected_venue  = available_venues.sample

      start_time, end_time = build_times

      if rand < 0.10
        days_ago = rand(1..60)
        start_time -= days_ago.days
        end_time   -= days_ago.days
      end

      cover = [true, false].sample

      Event.create!(
        date: start_time.to_date,
        start_time: start_time,
        end_time: end_time,
        description: event_descriptions.sample,
        cover: cover,
        cover_amount: cover ? rand(5..20) : nil,
        indoors: [true, false].sample,
        venue: selected_venue,
        artist: selected_artist,
        category: selected_artist.performance_type,
      )

      artist_event_counts[selected_artist.id] += 1
      venue_event_counts[selected_venue.id]  += 1
      events_created += 1
    end

    puts "  Created #{events_created} events for #{city}"
  end
end

# ----- EVENTS ONLY (also dev-only if you want it that way) -----
task event_data: :environment do
  unless Rails.env.development?
    puts "❌ This task is only intended for development."
    next
  end

  require "faker"
  require "http"
  require "uri"
  require "open-uri"

  puts "Deleting events..."
  Event.destroy_all

  artists = Artist.all
  puts "Creating events..."

  cities = Venue.distinct.pluck(:city).compact

  def build_times
    random_start = Faker::Time.between(from: DateTime.now, to: DateTime.now + 2.days)
    hour = random_start.hour
    minute = (random_start.min / 15.0).round * 15
    hour += 1 and minute = 0 if minute == 60
    start_dt = random_start.change(hour: hour, min: minute, sec: 0)
    base_durations = [1.hour, 1.5.hours, 2.hours, 2.5.hours, 3.hours, 4.hours]
    long_durations = [3.hours, 4.hours, 5.hours, 6.hours]
    duration = start_dt.hour >= 22 ? long_durations.sample : base_durations.sample
    [start_dt, start_dt + duration]
  end

  event_descriptions = [
    "Join us for an intimate acoustic night featuring local talent and cold drinks.",
    "Experience a soulful evening of blues and brews at your favorite neighborhood bar.",
    "Don't miss this high-energy cover band playing your favorite hits from the '90s to today.",
    "A solo singer-songwriter takes the stage with original songs and heartfelt lyrics.",
    "Enjoy a cozy evening of jazz and cocktails in a candle-lit setting.",
    "A rotating lineup of local acts brings variety to the mic.",
    "Come catch a one-night-only performance from a rising local artist.",
    "This duo blends guitar and harmonies into a perfect mix of old-school and modern covers.",
    "Live music under the stars featuring a mix of acoustic sets and upbeat originals.",
    "A relaxed Sunday set with brunch vibes, acoustic instruments, and feel-good music.",
  ]

  artist_event_counts = Hash.new(0)
  venue_event_counts = Hash.new(0)

  cities.each do |city|
    venues_in_city = Venue.where(city: city)
    next if venues_in_city.empty?

    puts "Creating events for #{city} (#{venues_in_city.count} venues)"

    attempts = 0
    events_created = 0
    max_attempts = 100

    while events_created < 30 && attempts < max_attempts
      attempts += 1

      available_artists = artists.select { |a| artist_event_counts[a.id] < 10 }
      available_venues  = venues_in_city.select { |v| venue_event_counts[v.id] < 10 }

      break if available_artists.empty? || available_venues.empty?

      selected_artist = available_artists.sample
      selected_venue  = available_venues.sample

      start_time, end_time = build_times

      if rand < 0.10
        days_ago = rand(1..60)
        start_time -= days_ago.days
        end_time   -= days_ago.days
      end

      cover = [true, false].sample

      Event.create!(
        date: start_time.to_date,
        start_time: start_time,
        end_time: end_time,
        description: event_descriptions.sample,
        cover: cover,
        cover_amount: cover ? rand(5..20) : nil,
        indoors: [true, false].sample,
        venue: selected_venue,
        artist: selected_artist,
        category: selected_artist.performance_type,
      )

      artist_event_counts[selected_artist.id] += 1
      venue_event_counts[selected_venue.id]  += 1
      events_created += 1
    end

    puts "  Created #{events_created} events for #{city}"
  end
end
