module Admin
  class EventImportRowsController < ApplicationController
    before_action :require_admin!

    def approve
      row = EventImportRow.find(params[:id])
      event = Event.new(
        venue_id: row.venue_id,
        artist_name: row.artist_name,
        date: row.date,
        start_time: row.start_time_str,
        end_time: row.end_time_str,
        import_source: "web",
        indoors: true,
        category: nil
      )

      if event.save
        row.update!(status: "created")
        redirect_to admin_event_import_path(row.event_import_batch_id),
                    notice: "Created event #{event.artist_name}"
      else
        redirect_to admin_event_import_path(row.event_import_batch_id),
                    alert: "Error creating event: #{event.errors.full_messages.join(', ')}"
      end
    end

    def destroy
      row = EventImportRow.find(params[:id])
      row.destroy
      redirect_to admin_event_import_path(row.event_import_batch_id),
                  notice: "Deleted proposed event."
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
  end
end
