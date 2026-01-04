module Admin
  class EventImportsController < ApplicationController
    before_action :require_admin!

    def index
      @cities = Venue.where.not(website: [nil, ""])
                     .where.not(city: [nil, ""])
                     .where(scrapable: true)
                     .distinct
                     .order(:city)
                     .pluck(:city)

      @city   = params[:city].presence
      @venues =
        if @city.present?
          Venue.where(city: @city)
               .where.not(website: [nil, ""])
               .where(scrapable: true)
               .order(:name)
        else
          []
        end

      @latest_batch = EventImportBatch.order(created_at: :desc).first
    end

    def create
      city        = params.require(:city)
      venue_ids   = Array(params[:venue_ids]).map(&:to_i).uniq
      use_browser = params[:use_browser] == "true"

      batch = EventImportBatch.create!(
        city:       city,
        status:     "pending",
        run_by_id:  current_user&.id
      )

      EventImports::RunJob.perform_later(
        city: city,
        run_by_id: current_user&.id,
        batch_id: batch.id,
        venue_ids: venue_ids.presence,
        use_browser: use_browser
      )

      msg_detail = venue_ids.present? ? " (#{venue_ids.size} venues selected)" : ""
      mode_detail = use_browser ? " [Browser Mode]" : ""
      redirect_to admin_event_import_path(batch), notice: "Running event import for #{city}#{msg_detail}#{mode_detail}…"
    end

    def show
      @batch = EventImportBatch.find(params[:id])
      @rows  = @batch.event_import_rows.includes(:venue)
      @conflicts = conflict_map(@rows)
    end

    def approve_all
      batch = EventImportBatch.find(params[:id])
      rows  = batch.event_import_rows.where(status: "proposed")
      
      created = 0

      rows.find_each do |r|
        begin
          venue = Venue.find(r.venue_id)

          # Build start_time (prefer UTC column; else build from date + HH:MM in venue tz)
          start_time_val =
            r.start_time_utc ||
            begin
              if r.date.present? && r.start_time_str.present?
                tz = ActiveSupport::TimeZone[venue.tz_name] || Time.zone
                sh, sm = r.start_time_str.split(":").map(&:to_i)
                tz.local(r.date.year, r.date.month, r.date.day, sh, sm)
              end
            end

          # Build end_time (prefer UTC column; else +3h from start_time)
          end_time_val =
            r.end_time_utc ||
            (start_time_val && start_time_val + 3.hours)

          event = Event.new(
            venue_id:     r.venue_id,
            artist_name:  r.artist_name,
            date:         r.date,          # Date
            start_time:   start_time_val,  # Time / ActiveSupport::TimeWithZone
            end_time:     end_time_val,    # Time / fallback applied
            import_source:"web",
            indoors:      true,
            cover:        false,
            category:     "Other"            
          )

          if event.save(validate: true)
            r.update!(status: "created")
            created += 1
          else
            # No rejected_reason column -> just mark rejected and optionally log
            r.update!(status: "rejected")
            Rails.logger.warn("[approve_all] Row #{r.id} rejected: #{event.errors.full_messages.join(', ')}")
          end
        rescue => e
          r.update!(status: "rejected")
          Rails.logger.warn("[approve_all] Row #{r.id} exception: #{e.class}: #{e.message}")
        end
      end


      redirect_to approve_summary_admin_event_import_path(batch)
    end

    def approve_summary
      @batch = EventImportBatch.find(params[:id])

      # Re-compute summary from DB (no flash dependency)
      created_rows = @batch.event_import_rows.where(status: "created")
      counts = created_rows.group(:venue_id).count
      @total = created_rows.count

      venues = Venue.where(id: counts.keys).index_by(&:id)
      @per_venue = counts.map { |venue_id, count| [venues[venue_id], count] }.select { |v, _| v.present? }
    end

    private

    def require_admin!
      unless is_admin?
        redirect_to root_path, alert: "Admins only."
      end
    end

    def is_admin?
      return false unless user_signed_in?
      admin_emails = ENV.fetch('ADMIN_EMAILS', 'admin@pickleball.co').split(',').map(&:strip)
      admin_emails.include?(current_user.email)
    end

    def conflict_map(rows)
      rows.each_with_object({}) do |r, h|
        next unless r.start_time_utc && r.end_time_utc
        overlaps = Event.where(venue_id: r.venue_id)
                        .where("start_time < ? AND end_time > ?", r.end_time_utc, r.start_time_utc)
                        .exists?
        h[r.id] = overlaps
      end
    end
  end
end
