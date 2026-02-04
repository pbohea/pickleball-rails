require "google/cloud/storage"

module Gcp
  class StorageClient
    def initialize(bucket_name:)
      @bucket_name = bucket_name
      @client = Google::Cloud::Storage.new
      @bucket = @client.bucket(@bucket_name)
      raise "GCS bucket not found: #{@bucket_name}" unless @bucket
    end

    def upload_file(local_path, dest_path)
      @bucket.create_file(local_path, dest_path)
      "gs://#{@bucket_name}/#{dest_path}"
    end

    def upload_io(io, dest_path, content_type: nil)
      file = @bucket.create_file(io, dest_path, content_type: content_type)
      "gs://#{@bucket_name}/#{file.name}"
    end

    def download_text(gs_uri)
      bucket, object = parse_gs_uri(gs_uri)
      b = @client.bucket(bucket)
      raise "GCS bucket not found: #{bucket}" unless b
      f = b.file(object)
      raise "GCS object not found: #{gs_uri}" unless f
      f.download.string
    end

    private

    def parse_gs_uri(uri)
      raise "Not a gs:// URI: #{uri}" unless uri.start_with?("gs://")
      rest = uri[5..]
      bucket, object = rest.split("/", 2)
      [bucket, object]
    end
  end
end
