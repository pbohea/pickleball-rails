module EventImports
  class RunJob < ApplicationJob
    queue_as :default

    def perform(city:, run_by_id:, batch_id:, venue_ids: nil, use_browser: false)
      run_by = User.find_by(id: run_by_id)
      EventImports::ScrapeAndParse.call(
        city: city,
        run_by: run_by,
        batch_id: batch_id,
        venue_ids: venue_ids,
        use_browser: use_browser
      )
    end
  end
end
