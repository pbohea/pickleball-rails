require "json"
require "net/http"

module ModelRunner
  class HttpClient
    def initialize(url:, token: nil, open_timeout: 10, read_timeout: 30)
      @uri = URI(url)
      @token = token
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def enqueue_analysis(video_uri:, desc:, start:, output_uri:)
      body = {
        video_uri: video_uri,
        desc: desc,
        start: start,
        output_uri: output_uri
      }

      response = request_json(:post, @uri, body)
      {
        request_id: response["request_id"] || response["job_id"] || response["id"],
        raw: response
      }
    end

    private

    def request_json(method, uri, body = nil)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      req = if method == :post
        Net::HTTP::Post.new(uri.request_uri)
      else
        Net::HTTP::Get.new(uri.request_uri)
      end

      req["Content-Type"] = "application/json"
      req["Authorization"] = "Bearer #{@token}" if @token.present?
      req.body = JSON.dump(body) if body

      resp = http.request(req)
      unless resp.is_a?(Net::HTTPSuccess)
        raise "Model runner HTTP error #{resp.code}: #{resp.body}"
      end

      return {} if resp.body.to_s.strip.empty?
      JSON.parse(resp.body)
    end
  end
end
