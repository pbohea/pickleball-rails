# lib/tasks/events_import.rake
namespace :events do
  desc "Run Claude web-search import for a given CITY (ENV: CITY=Chicago)"
  task import: :environment do
    city = ENV["CITY"].to_s.strip
    abort "Please provide CITY=..." if city.blank?

    puts "[events:import] Starting for city=#{city} (env=#{Rails.env})"

    # In rake, run sync (service) so you can see console output; admin UI uses the job.
    batch = EventImports::ScrapeAndParse.call(city:, run_by: nil)

    puts "[events:import] Batch ##{batch.id} status=#{batch.status} rows=#{batch.event_import_rows.count}"
    if batch.status == "finished" && batch.event_import_rows.none?
      puts "[events:import] WARNING: finished with no rows."
    end
  end
end
