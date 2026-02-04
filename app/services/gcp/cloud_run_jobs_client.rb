require "json"
require "net/http"
require "googleauth"

module Gcp
  class CloudRunJobsClient
    SCOPE = "https://www.googleapis.com/auth/cloud-platform".freeze

    def initialize(project:, region:)
      @project = project
      @region = region
    end

    def run_job(job_name, args:)
      uri = URI("https://run.googleapis.com/v2/projects/#{@project}/locations/#{@region}/jobs/#{job_name}:run")
      body = {
        overrides: {
          containerOverrides: [
            { args: args }
          ]
        }
      }
      resp = request_json(:post, uri, body)
      resp.fetch("name")
    end

    def get_execution(execution_name)
      uri = URI("https://run.googleapis.com/v2/#{execution_name}")
      request_json(:get, uri)
    end

    def execution_status(execution_name)
      payload = get_execution(execution_name)
      conditions = payload.dig("status", "conditions") || []
      completed = conditions.find { |c| c["type"] == "Completed" }
      started = conditions.find { |c| c["type"] == "Started" }
      if completed&.dig("status") == "True"
        :succeeded
      elsif completed&.dig("status") == "False"
        :failed
      elsif started&.dig("status") == "True"
        :running
      else
        :unknown
      end
    end

    private

    def request_json(method, uri, body = nil)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60

      req = if method == :post
        Net::HTTP::Post.new(uri.request_uri)
      else
        Net::HTTP::Get.new(uri.request_uri)
      end
      req["Authorization"] = "Bearer #{access_token}"
      req["Content-Type"] = "application/json"
      req.body = JSON.dump(body) if body

      resp = http.request(req)
      unless resp.is_a?(Net::HTTPSuccess)
        raise "Cloud Run API error #{resp.code}: #{resp.body}"
      end
      JSON.parse(resp.body)
    end

    def access_token
      creds = Google::Auth.get_application_default(SCOPE)
      creds.fetch_access_token!["access_token"]
    end
  end
end
