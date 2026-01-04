# app/jobs/event_imports/purge_job.rb
module EventImports
  class PurgeJob < ApplicationJob
    queue_as :default

    def perform(batch_id)
      batch = EventImportBatch.find_by(id: batch_id)
      return unless batch
      EventImportRow.where(event_import_batch_id: batch.id).delete_all
      batch.destroy!
    end
  end
end
