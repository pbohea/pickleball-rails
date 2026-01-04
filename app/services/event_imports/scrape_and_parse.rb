# frozen_string_literal: true

require 'selenium-webdriver'

module EventImports
  class ScrapeAndParse
    MAX_SITES     = 10
    TOOL_NAME     = "web_fetch"
    SEARCH_MODEL  = "claude-sonnet-4-20250514"
    TOOL_VERSION  = "web_fetch_20250910"
    HTTP_TIMEOUT  = 90 # seconds
    PREVIEW_BYTES = 1200
    BROWSER_TIMEOUT = 30 # seconds for browser operations

    def self.call(city:, run_by:, batch_id: nil, venue_ids: nil, use_browser: false)
      new(city: city, run_by: run_by, batch_id: batch_id, venue_ids: venue_ids, use_browser: use_browser).call
    end

    def initialize(city:, run_by:, batch_id: nil, venue_ids: nil, use_browser: false)
      @city       = city
      @run_by     = run_by
      @batch      = batch_id ? EventImportBatch.find_by(id: batch_id) : nil
      @venue_ids  = Array(venue_ids).presence
      @use_browser = use_browser
    end

    def call
      started_at = Time.current

      batch = (@batch || EventImportBatch.create!(
        city:       @city,
        status:     "pending",
        run_by_id:  @run_by&.id
      ))

      if batch.status == "pending"
        batch.update!(status: "running", started_at: Time.current)
      end

      log!(batch, :info, "BEGIN scrape city=#{@city} batch_id=#{batch.id} use_browser=#{@use_browser}")

      unless ENV["ANTHROPIC_KEY"].present?
        fail_and_raise!(batch, "Missing ENV['ANTHROPIC_KEY']")
      end

      venues = scope_venues(@city, @venue_ids)
      log!(batch, :info, @venue_ids.present? ? "venues.count=#{venues.size} (manual selection)" : "venues.count=#{venues.size} (max=#{MAX_SITES})")

      # Build exact URL map, host list, and subpath allowlist
      url_map, allowed_urls, domain_map, allowed_hosts = build_pages_and_domains(venues)
      log!(batch, :info,  "allowed_urls=#{allowed_urls.inspect}")
      log!(batch, :debug, "allowed_hosts=#{allowed_hosts.inspect}")

      if allowed_urls.empty?
        finish!(batch, :finished, "No valid event page URLs from websites in #{@city}", started_at)
        return batch
      end

      # NEW: Try browser scraping first if enabled
      if @use_browser
        events = scrape_with_browser(allowed_urls, url_map, batch)
        if events.any?
          log!(batch, :info, "browser_scrape.events=#{events.size}")

          created = 0
          events.first(100).each_with_index do |e, idx|
            begin
              persist_event_row!(batch, e, idx)
              created += 1
            rescue => row_err
              log!(batch, :error, "row_error idx=#{idx} #{row_err.class}: #{row_err.message}")
            end
          end
          log!(batch, :info, "rows.created=#{created}")

          finish!(batch, :finished, nil, started_at)
          return batch
        else
          log!(batch, :warn, "browser_scrape failed, falling back to web_fetch")
        end
      end

      # Fallback to original web_fetch method
      payload = build_payload(allowed_hosts, domain_map, allowed_urls, url_map)
      log!(batch, :debug, "anthropic.payload.summary=" \
        "{model=#{payload[:model]}, tools=[#{payload[:tools].map { |t| t[:name] || t[:type] }.join(", ")}], max_tokens=#{payload[:max_tokens]}, temperature=#{payload[:temperature]}}")

      response, latency_ms = post_anthropic(payload)
      log!(batch, :info, "anthropic.http status=#{response.status.to_i} latency_ms=#{latency_ms}")

      rid = response.headers["x-request-id"] || response.headers["request-id"]
      log!(batch, :debug, "anthropic.request_id=#{rid}") if rid

      preview = response.body.to_s[0, PREVIEW_BYTES]
      log!(batch, :debug, "anthropic.body.preview=#{preview.inspect}")

      # --- Save Claude debug info ---
      body    = safe_json_parse(response.body.to_s)
      content = body.is_a?(Hash) ? (body["content"] || []) : []
      tool_names = content.select { |c| c.is_a?(Hash) && c["type"] == "tool_use" }.map { |c| c["name"] }.compact

      batch.update_columns(
        provider_request_id: rid,
        body_preview:        preview,
        raw_response_json:   body,
        tool_names:          tool_names
      )
      # --- end debug info ---

      unless response.status.success?
        fail_and_raise!(batch, "Anthropic non-200: #{response.status} — body: #{preview}")
      end

      body    = safe_json_parse(response.body.to_s)
      content = body.is_a?(Hash) ? (body["content"] || []) : []
      log!(batch, :debug, "anthropic.content.types=#{content.map { |c| c["type"] }.tally}")

      tool_names = content.select { |c| c.is_a?(Hash) && c["type"] == "tool_use" }.map { |c| c["name"] }.compact
      log!(batch, :debug, "tool_use.names=#{tool_names.inspect}")

      answer_inputs = extract_answer_json_blocks(content)
      log!(batch, :info, "answer_json.blocks=#{answer_inputs.size}")
      answer_inputs.each_with_index do |inp, i|
        log!(batch, :debug, "answer_json[#{i}].preview=#{inp.to_json[0, 300]}")
      end

      raw_events = flatten_events(answer_inputs)
      log!(batch, :info, "events.raw_count=#{raw_events.size}")

      # Enforce exact URL whitelist during normalization
      events = normalize_events(raw_events, domain_map, url_map, allowed_urls)
      log!(batch, :info, "events.normalized_count=#{events.size}")

      append_note!(batch, "Zero events after strict URL filtering.") if events.empty?

      created = 0
      events.first(100).each_with_index do |e, idx|
        begin
          persist_event_row!(batch, e, idx)
          created += 1
        rescue => row_err
          log!(batch, :error, "row_error idx=#{idx} #{row_err.class}: #{row_err.message}")
        end
      end
      log!(batch, :info, "rows.created=#{created}")

      finish!(batch, :finished, nil, started_at)

      begin
        EventImports::PurgeJob.set(wait: 24.hours).perform_later(batch.id)
        log!(batch, :debug, "purge_job.enqueued batch_id=#{batch.id}")
      rescue => purge_err
        log!(batch, :error, "purge_job.enqueue_failed #{purge_err.class}: #{purge_err.message}")
      end

      batch
    rescue => e
      msg = "#{e.class}: #{e.message}"
      log!(@batch || batch, :error, "FATAL #{msg}\n#{Array(e.backtrace).first(10).join("\n")}")
      begin
        (batch || @batch)&.update!(status: "failed", finished_at: Time.current, notes: trim_notes("#{(batch || @batch)&.notes}\n#{msg}"))
      rescue => upd_err
        Rails.logger.error("[EventImports] failed_to_update_batch_status #{upd_err.class}: #{upd_err.message}")
      end
      raise
    end

    private

    def slim_html(html)
      # Remove <script>...</script>
      html = html.gsub(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/im, "")

      # Remove <style>...</style>
      html = html.gsub(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/im, "")

      # Remove HTML comments
      html = html.gsub(/<!--.*?-->/m, "")

      # Collapse whitespace
      html = html.gsub(/\s+/, " ")

      html
    end

    # NEW: Browser-based scraping method
    def scrape_with_browser(allowed_urls, url_map, batch)
      events = []

      # Setup headless Chrome with anti-detection settings
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless=new')  # Use new headless mode (less detectable)
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-gpu')
      options.add_argument('--window-size=1920,1080')
      options.add_argument('--disable-blink-features=AutomationControlled')
      options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')

      # Exclude automation flags
      options.add_preference('excludeSwitches', ['enable-automation'])
      options.add_preference('useAutomationExtension', false)

      driver = Selenium::WebDriver.for(:chrome, options: options)
      driver.manage.timeouts.page_load = BROWSER_TIMEOUT
      driver.manage.timeouts.script_timeout = BROWSER_TIMEOUT

      allowed_urls.each do |url|
        begin
          log!(batch, :info, "browser_fetch url=#{url}")

          driver.navigate.to(url)

          # Wait for page to be ready
          begin
            wait = Selenium::WebDriver::Wait.new(timeout: 5)
            wait.until { driver.execute_script("return document.readyState") == "complete" }
          rescue Selenium::WebDriver::Error::TimeoutError
            log!(batch, :warn, "browser_fetch timeout waiting for readyState, continuing anyway")
          end

          # Wait for Cloudflare challenge to complete
          log!(batch, :warn, "browser_fetch: Waiting for Cloudflare challenge...")
          sleep(10)  # Wait longer for Cloudflare

          # Check if still on Cloudflare page
          if driver.page_source.include?("Just a moment") || driver.page_source.include?("Cloudflare")
            log!(batch, :error, "browser_fetch: Still on Cloudflare challenge page after 10s")
            # Try waiting even longer
            sleep(10)
          end

          # Additional wait for dynamic content
          sleep(3)

          # Execute JavaScript to scroll and ensure all content is loaded
          driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
          sleep(2)
          driver.execute_script("window.scrollTo(0, 0);")
          sleep(1)

          # Get the full page source after JS execution
          page_source = driver.page_source

          log!(batch, :warn, "browser_fetch.content_length=#{page_source.length}")

          # Send the rendered HTML to Claude for intelligent extraction
          venue_id = url_map[url]
          extracted_events = extract_events_with_claude(page_source, url, venue_id, batch)

          events.concat(extracted_events)
          log!(batch, :info, "browser_fetch.events_found=#{extracted_events.size} url=#{url}")

        rescue => e
          log!(batch, :error, "browser_fetch.error url=#{url} #{e.class}: #{e.message}")
        end
      end

      events
    ensure
      driver&.quit
    end

    # NEW: Send rendered HTML to Claude for intelligent extraction
    def extract_events_with_claude(html, source_url, venue_id, batch)
      # Truncate HTML if too long (Claude has token limits)
      # ---- NEW: Reduce HTML before sending to Claude ----
      slimmed_html = slim_html(html)

      max_html_length = 120_000  # MUCH safer for Anthropic rate limits
      truncated_html =
        if slimmed_html.length > max_html_length
          slimmed_html[0...max_html_length] + "\n[...truncated]"
        else
          slimmed_html
        end

      log!(batch, :warn, "extract_events_with_claude: Sending #{truncated_html.length} chars to Claude (after reduction)")


      payload = {
        model: SEARCH_MODEL,
        max_tokens: 2000,
        temperature: 0.2,
        messages: [
          {
            role: "user",
            content: <<~PROMPT
              You are analyzing a live music venue's event page. The HTML below has been rendered with JavaScript, so all dynamic content is visible.

              Extract ALL upcoming live music events from this HTML. For each event, extract:
              - artist_name (required)
              - date (required) - in format like "Saturday, November 26" or "2025-11-26"
              - start_time (if visible) - like "10PM", "9:30PM", etc.
              - end_time (if visible)

              Important:
              - Extract events regardless of date (we'll filter later)
              - If you see dates without years (like "November 26"), include them as-is
              - Skip generic text like "Live Music", "Upcoming Shows" - only extract actual performer names
              - Each event should have a specific artist/band name

              Return your answer as JSON in this exact format:
              {
                "events": [
                  {
                    "artist_name": "Band Name",
                    "date": "Saturday, November 26",
                    "start_time": "10PM",
                    "end_time": null
                  }
                ]
              }

              HTML Content:
              #{truncated_html}
            PROMPT
          }
        ]
      }

      begin
        response, _latency = post_anthropic(payload)

        unless response.status.success?
          log!(batch, :error, "extract_events_with_claude: API error status=#{response.status}")
          return []
        end

        body = safe_json_parse(response.body.to_s)
        content = body.is_a?(Hash) ? (body["content"] || []) : []

        # Extract the text response and parse JSON from it
        text_content = content.find { |c| c["type"] == "text" }&.dig("text") || ""
        log!(batch, :warn, "extract_events_with_claude: Claude response preview: #{text_content[0..500]}")

        # Try to extract JSON from the text (handle various formats)
        json_str = text_content
        # Remove markdown code blocks if present
        json_str = json_str.gsub(/```json\s*/m, '').gsub(/```\s*$/m, '')
        # Find JSON object
        json_match = json_str.match(/\{.*"events".*\}/m)

        if json_match
          result = JSON.parse(json_match[0])
          raw_events = result["events"] || []
          log!(batch, :warn, "extract_events_with_claude: Claude found #{raw_events.size} raw events")

          # Normalize and filter events
          normalized = raw_events.filter_map do |e|
            # Parse and validate date
            date = parse_date_flex(e["date"])
            next unless date && date >= Date.current

            # Normalize to match expected format
            {
              "venue_id" => venue_id,
              "source_url" => source_url,
              "artist_name" => e["artist_name"],
              "date" => date.iso8601,
              "start_time" => normalize_time_str(e["start_time"]),
              "end_time" => normalize_time_str(e["end_time"])
            }
          end

          log!(batch, :warn, "extract_events_with_claude: Normalized to #{normalized.size} events")
          normalized
        else
          log!(batch, :error, "extract_events_with_claude: Could not parse JSON from response")
          []
        end
      rescue => e
        log!(batch, :error, "extract_events_with_claude: Exception #{e.class}: #{e.message}")
        []
      end
    end

    # OLD: Parse events directly from HTML (for browser scraping) - DEPRECATED
    def parse_events_from_html(html, source_url, venue_id)
      events = []

      # Use Nokogiri to parse the HTML
      require 'nokogiri'
      doc = Nokogiri::HTML(html)

      # Look for event patterns - adjust selectors based on actual HTML structure
      event_selectors = [
        '.event', '.show', '[class*="event"]', '[class*="show"]',
        '[class*="upcoming"]', '.listing', '[class*="listing"]'
      ]

      event_selectors.each do |selector|
        doc.css(selector).each do |event_element|
          begin
            # Extract date
            date_text = event_element.text.match(/(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),?\s*(January|February|March|April|May|June|July|August|September|October|November|December)\s*\d{1,2}/i)&.to_s
            next unless date_text.present?

            # Extract time
            time_text = event_element.text.match(/\d{1,2}:?\d{0,2}\s*(PM|AM)/i)&.to_s

            # Skip if no time found (likely a duplicate or container element)
            next if time_text.blank?

            # Extract artist name
            artist_patterns = [
              event_element.css('.artist, .performer, .band, [class*="artist"], [class*="performer"], [class*="band"]').text.strip,
              event_element.css('h1, h2, h3, h4, h5, h6').text.strip,
              event_element.text.split("\n").find { |line| line.strip.present? && !line.match?(/(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)/i) }&.strip
            ].compact.reject(&:blank?)

            artist_name = artist_patterns.first
            next unless artist_name.present?

            # Skip generic text that's not artist names
            next if artist_name.match?(/(upcoming|shows|events|live music)/i)

            events << {
              "venue_id" => venue_id,
              "venue" => nil,
              "artist_name" => artist_name,
              "date" => date_text,
              "start_time" => normalize_time_str(time_text),
              "end_time" => nil,
              "source_url" => source_url
            }
          rescue => e
            # Skip individual parsing errors
            next
          end
        end
      end

      # Filter out events without required fields and normalize dates
      events.filter_map do |e|
        next unless e["artist_name"].present? && e["date"]

        date = parse_date_flex(e["date"])
        next unless date && date >= Date.current

        e["date"] = date.iso8601
        e
      end
    end

    # ---------- Venue scoping ----------
    def scope_venues(city, venue_ids)
      scope = Venue.where.not(website: [nil, ""])
      scope = scope.where(city: city) if city.present?
      scope = scope.where(id: venue_ids) if venue_ids.present?
      scope = scope.limit(MAX_SITES) unless venue_ids.present?
      scope.order(:name)
    end

    # ---------- Exact event pages + Domains ----------
    def build_pages_and_domains(venues)
      allowed_urls = venues.filter_map { |v|
        u = v.website.to_s.strip
        URI.parse(u) && u.presence
      }.uniq

      url_map = venues.each_with_object({}) { |v, h|
        u = v.website.to_s.strip
        h[u] = v.id if u.present?
      }

      domain_map = venues.each_with_object({}) { |v, h|
        begin
          host = URI.parse(v.website).host&.downcase&.sub(/\Awww\./, "")
          h[host] = v.id if host.present?
        rescue
        end
      }

      allowed_domains = allowed_urls.filter_map do |u|
        begin
          host = URI.parse(u).host&.downcase
          next unless host
          bare = host.sub(/\Awww\./, "")
          [bare, "www.#{bare}"]
        rescue
          nil
        end
      end.flatten.compact.uniq

      [url_map, allowed_urls, domain_map, allowed_domains]
    end

    # ---------- Anthropic payload ----------
    def build_payload(allowed_domains, domain_map, allowed_urls, url_map)
      date_start = Date.current
      date_end   = date_start + 30

      {
        model: SEARCH_MODEL,
        max_tokens: 2000,
        temperature: 0.2,
        tools: [
          {
            type: TOOL_VERSION,
            name: TOOL_NAME,
            allowed_domains: allowed_domains,
            max_uses: [allowed_urls.size, 12].min.clamp(1, 12),
            citations: { enabled: true },
            max_content_tokens: 60_000
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
                      venue_id:    { type: ["integer","null"] },
                      venue:       { type: ["string","null"] },
                      artist_name: { type: "string" },
                      date:        { type: "string" },
                      start_time:  { type: ["string","null"] },
                      end_time:    { type: ["string","null"] },
                      source_url:  { type: ["string","null"], format: "uri" }
                    },
                    required: %w[artist_name date],
                    additionalProperties: false
                  }
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
            content: <<~PROMPT
              You are STRICTLY LIMITED to these exact event page URLs (provided by our database).

              Allowed URLs (exact-match only):
              #{allowed_urls.to_json}

              URL→VenueID map:
              #{url_map.to_json}

              Domain→VenueID map (for reference only):
              #{domain_map.to_json}

              Task:
              • For each URL in Allowed URLs, call the web_fetch tool with that exact URL to retrieve the page content.
              • Do NOT follow links or fetch any other URL/path.
              - The page you are given may have information besides live events. Ignore that and find the events.
              • Extract live music events within the next 30 days (#{date_start.iso8601}..#{date_end.iso8601}).
              • Return ONLY via "answer_json": { events: [...] }.
              • If a page has no parsable events, still return answer_json with events: [].

              Output rules:
              • Each event MUST include { artist_name, date }. Include start_time/end_time if present; leave null if not shown.
              • Set venue_id using the URL→VenueID map.
              • Set source_url to the EXACT Allowed URL where the event appears.
              • Reject anything that is not on the Allowed URLs list.
            PROMPT
          }
        ]
      }
    end

    def post_anthropic(payload)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      resp = HTTP
        .headers(
          "Content-Type"       => "application/json",
          "x-api-key"          => ENV.fetch("ANTHROPIC_KEY"),
          "anthropic-version"  => "2023-06-01",
          "anthropic-beta"     => "web-fetch-2025-09-10"
        )
        .timeout(HTTP_TIMEOUT)
        .post("https://api.anthropic.com/v1/messages", body: JSON.dump(payload))
      t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      [resp, ((t1 - t0) * 1000).round]
    rescue HTTP::TimeoutError => e
      raise("Anthropic timeout after #{HTTP_TIMEOUT}s: #{e.message}")
    rescue => e
      raise("Anthropic request failed: #{e.class}: #{e.message}")
    end

    # ---- Response extraction ----
    def extract_answer_json_blocks(content)
      return [] unless content.is_a?(Array)
      content
        .select { |c| c.is_a?(Hash) && c["type"] == "tool_use" && c["name"] == "answer_json" }
        .map    { |blk| blk["input"] || {} }
    end

    def flatten_events(answer_inputs)
      answer_inputs.flat_map { |inp| Array(inp["events"]) }.first(200)
    end

    # ---- Normalization ----
    def normalize_events(raw_events, domain_map, url_map, allowed_urls)
      whitelist = allowed_urls.to_set

      raw_events.filter_map do |e|
        artist = e["artist_name"].to_s.strip
        date_s = e["date"].to_s.strip
        next if artist.blank? || date_s.blank?

        date = parse_date_flex(date_s)
        next unless date
        next if date < Date.current || date > (Date.current + 30)

        source_url = e["source_url"].to_s.strip
        venue_id   = e["venue_id"]

        if whitelist.include?(source_url)
          # ok
        else
          if venue_id && (replacement = url_map.key(venue_id))
            source_url = replacement
          else
            next
          end
        end

        next unless whitelist.include?(source_url)
        venue_id ||= url_map[source_url]
        next unless venue_id

        {
          "venue_id"    => venue_id,
          "venue"       => e["venue"].presence,
          "artist_name" => artist,
          "date"        => date.iso8601,
          "start_time"  => normalize_time_str(e["start_time"]),
          "end_time"    => normalize_time_str(e["end_time"]),
          "source_url"  => source_url
        }
      end
    end

    def parse_date_flex(s)
      return nil if s.blank?
      return Date.iso8601(s) rescue nil if s.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      # Parse the date, defaulting to current year
      parsed = Time.zone.parse(s)&.to_date rescue nil
      return nil unless parsed

      # If the parsed date is in the past, assume it's next year
      if parsed < Date.current
        # Try adding a year
        parsed = parsed.next_year
      end

      parsed
    end

    def normalize_time_str(s)
      return nil if s.blank?
      str = s.to_s.strip.downcase
      return "12:00" if str == "noon"
      return "00:00" if str == "midnight"

      if str =~ /\A(\d{1,2})(?::?(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)\z/i
        h = Regexp.last_match(1).to_i
        m = Regexp.last_match(2).to_i
        ampm = Regexp.last_match(3)
        pm = ampm.to_s.include?("p")
        h = (h % 12) + (pm ? 12 : 0)
        return format("%02d:%02d", h, m)
      end

      if str =~ /\A(\d{1,2}):(\d{2})\z/
        h = Regexp.last_match(1).to_i
        m = Regexp.last_match(2).to_i
        return nil if h > 23 || m > 59
        return format("%02d:%02d", h, m)
      end

      nil
    end

    # ---- Persistence ----
    def persist_event_row!(batch, e, idx)
      venue_id = e["venue_id"]
      venue    = Venue.find_by(id: venue_id)
      raise ArgumentError, "unknown venue_id=#{venue_id} for event idx=#{idx}" unless venue

      if e["start_time"].blank?
        raise ArgumentError, "missing start_time for event idx=#{idx} (artist=#{e["artist_name"]})"
      end

      start_local = parse_local_datetime(venue.tz_name, e["date"], e["start_time"])
      end_local   = if e["end_time"].present?
                      parse_local_datetime(venue.tz_name, e["date"], e["end_time"])
                    else
                      start_local&.+(3.hours)
                    end

      EventImportRow.create!(
        event_import_batch: batch,
        venue_id:           venue.id,
        artist_name:        e["artist_name"],
        date:               Date.parse(e["date"]),
        start_time_str:     e["start_time"],
        end_time_str:       e["end_time"],
        start_time_utc:     start_local&.utc,
        end_time_utc:       end_local&.utc,
        source_url:         e["source_url"],
        raw_json:           e,
        status:             "proposed"
      )
    end

    def parse_local_datetime(tz_name, date_str, hhmm)
      return nil if date_str.blank? || hhmm.blank?
      h, m = hhmm.split(":").map(&:to_i)
      zone = ActiveSupport::TimeZone[tz_name] || Time.zone
      d    = Date.parse(date_str)
      zone.local(d.year, d.month, d.day, h, m)
    end

    def safe_json_parse(str)
      JSON.parse(str)
    rescue => e
      { "parse_error" => "#{e.class}: #{e.message}" }
    end

    # ---------- Batch status + logging helpers ----------
    def finish!(batch, status_sym, note, started_at)
      batch.update!(
        status:      status_sym.to_s,
        finished_at: Time.current,
        notes:       note ? trim_notes([batch.notes, note].compact.join("\n")) : batch.notes
      )
      dur_ms = ((Time.current - started_at) * 1000).round
      log!(batch, :info, "END status=#{status_sym} duration_ms=#{dur_ms}")
    end

    def fail_and_raise!(batch, message)
      batch.update!(status: "failed", finished_at: Time.current, notes: trim_notes([batch.notes, message].compact.join("\n")))
      raise(message)
    end

    def log!(batch, level, message)
      line = "[EventImports] #{message}"
      case level
      when :debug then Rails.logger.debug(line)
      when :info  then Rails.logger.info(line)
      when :warn  then Rails.logger.warn(line)
      when :error then Rails.logger.error(line)
      else Rails.logger.info(line)
      end

      if [:warn, :error].include?(level)
        begin
          timestamp = Time.current.strftime("%H:%M:%S")
          snippet = "#{timestamp} #{message}".to_s.first(600)
          batch.update_columns(notes: trim_notes([batch.notes, snippet].compact.join("\n")))
        rescue => e
          Rails.logger.error("[EventImports] notes_append_failed #{e.class}: #{e.message}")
        end
      end
    end

    def append_note!(batch, text)
      return unless batch && text.present?
      batch.update_columns(notes: trim_notes([batch.notes, text].compact.join("\n")))
    rescue => e
      Rails.logger.error("[EventImports] append_note_failed #{e.class}: #{e.message}")
    end

    def trim_notes(s, max_len: 10_000)
      s = s.to_s
      return s if s.bytesize <= max_len
      tail = s.last(max_len - 20)
      "[truncated]\n" + tail
    end
  end
end
