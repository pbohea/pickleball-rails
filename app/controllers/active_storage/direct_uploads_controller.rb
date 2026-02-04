class ActiveStorage::DirectUploadsController < ActiveStorage::BaseController
  def create
    super
  rescue StandardError => e
    Rails.logger.error(
      "DirectUpload error: #{e.class} #{e.message}\n" \
      "#{e.backtrace&.first(20)&.join("\n")}"
    )
    render json: { error: e.message }, status: :internal_server_error
  end
end
