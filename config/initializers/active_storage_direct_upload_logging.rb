# Temporary diagnostic logging for direct upload errors.
ActiveSupport.on_load(:action_controller) do
  ActiveStorage::DirectUploadsController.class_eval do
    unless method_defined?(:create_without_logging)
      alias_method :create_without_logging, :create

      def create
        create_without_logging
      rescue StandardError => e
        Rails.logger.error(
          "DirectUpload error: #{e.class} #{e.message}\n" \
          "#{e.backtrace&.first(20)&.join("\n")}"
        )
        render json: { error: e.message }, status: :internal_server_error
      end
    end
  end
end
