module PushNotifications
  class ApnsSender
    def initialize(logger: Rails.logger)
      @logger = logger
    end

    def send_analysis_complete(user:, video:)
      return unless apns_configured?

      tokens = user.notification_tokens.where(platform: "iOS").pluck(:token).uniq
      return if tokens.empty?

      connection = Apnotic::Connection.new(
        auth_method: :token,
        cert_path: ENV.fetch("APNS_KEY_PATH"),
        key_id: ENV.fetch("APNS_KEY_ID"),
        team_id: ENV.fetch("APNS_TEAM_ID"),
        url: apns_url
      )

      tokens.each do |token|
        notification = Apnotic::Notification.new(token)
        notification.topic = ENV.fetch("APNS_BUNDLE_ID")
        notification.alert = {
          title: "Analysis complete",
          body: "Your pickleball video is ready."
        }
        notification.sound = "default"
        notification.payload = {
          video_id: video.id,
          path: "/videos/#{video.id}"
        }
        connection.push(notification)
      end
    rescue StandardError => e
      @logger.error("APNs push failed: #{e.class} #{e.message}")
    ensure
      connection&.close
    end

    private

    def apns_configured?
      required = %w[APNS_KEY_PATH APNS_KEY_ID APNS_TEAM_ID APNS_BUNDLE_ID]
      missing = required.select { |key| ENV[key].blank? }
      if missing.any?
        @logger.info("APNs disabled. Missing: #{missing.join(", ")}")
        return false
      end
      true
    end

    def apns_url
      Rails.env.production? ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com"
    end
  end
end
