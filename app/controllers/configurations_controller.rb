class ConfigurationsController < ApplicationController
  def ios_v1
    render json: {
      settings: {
        # Enable swipe to go back
        swipe_to_refresh_enabled: true,
        # Preload pages for faster navigation
        preload_enabled: true,
      },
      rules: [
        {
          patterns: [
            "/new$",
           # "/edit$",
            #"/about$",
            #"/artists_about$",
            #"/owners_about$"
          ],
          properties: {
            context: "modal",
            # Dismiss modal with swipe gesture
            modal_dismiss_gesture: "down",
          },
        },
        {
          patterns: [
            "^/map.*",
            "^/events/map.*",
          ],
          properties: {
            view_controller: "map",
          },
        },
        {
          patterns: [
            "^/venues/\\d+$",
          ],
          properties: {
            context: "default",
            presentation: "push",
            # This can help with faster transitions
            preload: true,
          },
        },
        # Add artist navigation optimization
        {
          patterns: [
            "^/artists/\\d+$",
          ],
          properties: {
            context: "default",
            presentation: "push",
            preload: true,
          },
        },
        # Handle external links properly
        {
          patterns: [
            "^https?://(?!.*your-domain\\.com).*",
          ],
          properties: {
            context: "external",
          },
        },
      ],
    }
  end
end
