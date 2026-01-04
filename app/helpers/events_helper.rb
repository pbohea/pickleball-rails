# app/helpers/events_helper.rb
module EventsHelper
  # Venue-local date options (e.g., next 60 days)
  def date_options(venue, days_ahead: 60)
    tz = ActiveSupport::TimeZone[venue.tz_name]
    start_day = tz.today
    (0..days_ahead).map do |i|
      day = start_day + i
      [day.strftime("%A, %b %-d"), day.to_s] # [display, value]
    end
  end

  # Venue-local start times for a chosen venue-local date
  # Returns [["7:00 PM","19:00"], ...]
  def time_options(venue, selected_date_str, interval_minutes: 15, open_hour: 8)
    tz = ActiveSupport::TimeZone[venue.tz_name]
    date = Date.parse(selected_date_str) rescue tz.today
    
    # Get current time in venue's timezone
    now_in_venue = Time.current.in_time_zone(tz)
    is_today = date == now_in_venue.to_date

    # Start at 8:00 AM local
    start_local = tz.local(date.year, date.month, date.day, open_hour, 0)
    
    # If it's today, adjust start time to next 15-minute window after current time
    if is_today
      # Round up to next 15-minute interval
      minutes_to_add = (15 - (now_in_venue.min % 15)) % 15
      next_slot = now_in_venue + minutes_to_add.minutes
      
      # If next slot is before opening hours, use opening time
      # If next slot is after opening time, use the next slot
      start_local = [start_local, next_slot].max
      
      # Round to nearest 15-minute interval
      remainder = start_local.min % interval_minutes
      if remainder != 0
        start_local = start_local + (interval_minutes - remainder).minutes
      end
    end

    # End at 11:45 PM local
    end_local = tz.local(date.year, date.month, date.day, 23, 46)

    slots = []
    t = start_local
    while t <= end_local
      slots << [t.strftime("%-I:%M %p"), t.strftime("%H:%M")]
      t += interval_minutes.minutes
    end
    slots
  end

  # Venue-local end times after a chosen start time; ensure > start; allow overnight
  # Returns [["8:00 PM","20:00"], ...]
  def end_time_options(venue, selected_date_str, start_time_str, interval_minutes: 15)
    tz = ActiveSupport::TimeZone[venue.tz_name]
    date = Date.parse(selected_date_str) rescue tz.today
    sh, sm = start_time_str.split(":").map(&:to_i)

    start_local = tz.local(date.year, date.month, date.day, sh, sm)

    # End window is 4:00 AM next day
    end_local = tz.local(date.year, date.month, date.day, 4, 0) + 1.day

    slots = []
    t = start_local + interval_minutes.minutes # first slot after start
    while t <= end_local
      slots << [t.strftime("%-I:%M %p"), t.strftime("%H:%M")]
      t += interval_minutes.minutes
    end
    slots
  end

    def event_db_artists(event)
    event.all_artists.includes(image_attachment: :blob)
  end

  def event_manual_names(event)
    names = event.event_artists.where(artist_id: nil).pluck(:manual_name)
    primary_manual = event.artist_id.present? ? "" : event.artist_name.to_s
    ([primary_manual] + names).map(&:strip).reject(&:blank?).uniq
  end

end
