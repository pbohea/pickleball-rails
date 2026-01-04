

namespace :events do
  desc "Scrape web for <% city %> live music events"
  task pull: :environment do
    puts "Running Events Search"

    require "json"
    require "http"
    require "dotenv/load"

    API_KEY  = ENV.fetch("ANTHROPIC_KEY")
    ENDPOINT = "https://api.anthropic.com/v1/messages"

    payload = {
      model: "claude-4-5-sonnet-20250219",
      max_tokens: 1024,
      temperature: 0.2,
      tools: [
        {
          type: "web_search_20250305",
          name: "web_search",
          allowed_domains: [venue_websites],
          max_uses: 5
        },
        {
          type: "custom",
          name: "answer_json",
          description: "Return the final structured answer.",
          input_schema: {
            type: "object",
            properties: {
              events: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    name:        { type: "string" },
                    venue:       { type: "string" },
                    address:     { type: "string" },
                    date:        { type: "string", format: "date" },
                    start_time:  { type: "string", pattern: "^\\d{2}:\\d{2}$" },
                    price:       { type: "string" },
                    ticket_url:  { type: "string", format: "uri" },
                    description: { type: "string" }
                  },
                  required: %w[name venue address date start_time],
                  additionalProperties: false
                }
              },
              source_urls: {
                type: "array",
                items: { type: "string", format: "uri" }
              }
            },
            required: ["events"],
            additionalProperties: false
          }
        }
      ],
      messages: [
        {
          role: "user",
          content: "Search for bars in Chicago with live music events in the next 7 days. Return the answer as JSON."
        }
      ]
    }

    max_retries = 3
    retry_count = 0
    retry_delay = 5 # seconds

    begin
      while retry_count <= max_retries
        begin
          puts "Attempt #{retry_count + 1}/#{max_retries + 1}"
          
          response = HTTP
            .headers(
              "Content-Type" => "application/json",
              "x-api-key"    => API_KEY,
              "anthropic-version" => "2023-06-01"
            )
            .timeout(60) # Add a timeout to prevent hanging
            .post(ENDPOINT, body: JSON.dump(payload))
          
          response_body = JSON.parse(response.body)
          
          if response.status.success?
            # Process the successful response
            tool_outputs = response_body.dig("content", 0, "tool_use")
            
            if tool_outputs && tool_outputs["name"] == "answer_json"
              events_data = tool_outputs.dig("input", "events")
              puts "Found #{events_data.size} events:"
              events_data.each do |event|
                puts "- #{event['name']} at #{event['venue']} on #{event['date']} at #{event['start_time']}"
              end
              
              # Save to database or do other processing here
              # events_data.each { |event_data| Event.create!(event_data) }

              # Full output for debugging if needed
              # puts JSON.pretty_generate(response_body)
              
              break # Exit the retry loop on success
            else
              puts "No events data found in response"
              puts JSON.pretty_generate(response_body)
              break # Exit retry loop as the API did respond, just not with events
            end
          elsif response.status.code == 529
            # Overloaded error - retry with backoff
            retry_count += 1
            if retry_count <= max_retries
              sleep_time = retry_delay * (2 ** (retry_count - 1)) # Exponential backoff
              puts "API overloaded. Retrying in #{sleep_time} seconds..."
              sleep(sleep_time)
            else
              puts "Maximum retries reached. API still overloaded."
              puts JSON.pretty_generate(response_body)
            end
          else
            # Other error - display and exit
            puts "Error: #{response.status}"
            puts JSON.pretty_generate(response_body)
            break
          end
        rescue HTTP::Error => e
          puts "HTTP error: #{e.message}"
          retry_count += 1
          if retry_count <= max_retries
            sleep_time = retry_delay * (2 ** (retry_count - 1))
            puts "Retrying in #{sleep_time} seconds..."
            sleep(sleep_time)
          else
            puts "Maximum retries reached after HTTP errors."
          end
        end
      end
    rescue => e
      puts "Exception: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end
end
