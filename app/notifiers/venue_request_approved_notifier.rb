class VenueRequestApprovedNotifier < ApplicationNotifier
  required_param :venue_request
  
  deliver_by :ios do |config|
    config.device_tokens = -> {
      recipient.notification_tokens.where(platform: :iOS).pluck(:token)
    }
    config.format = ->(apn) {
      puts "🚨 Formatting venue request approved APN payload"
      apn.alert = "Your venue request has been approved!"
      apn.custom_payload = {
        path: venue_path(params[:venue_request].venue),
        venue_id: params[:venue_request].venue_id,
        venue_name: params[:venue_request].name
      }
    }
    credentials = Rails.application.credentials.ios
    config.bundle_identifier = credentials.bundle_identifier
    config.key_id = credentials.key_id
    config.team_id = credentials.team_id
    config.apns_key = credentials.apns_key

    # config.development = Rails.env.local?

    #### must change the below to false for test flight
    
    config.development = false

  end
end
