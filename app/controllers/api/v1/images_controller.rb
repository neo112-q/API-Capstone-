class Api::V1::ImagesController < ApplicationController
  before_action :set_s3_client

  def show
    key = params[:key]
    ext = File.extname(key).delete(".")
    content_type = case ext
    when "png" then "image/png"
    when "jpg", "jpeg" then "image/jpeg"
    when "gif" then "image/gif"
    when "webp" then "image/webp"
    else "application/octet-stream"
    end

    data = @s3_client.get_object(bucket: @bucket_name, key: key).body.read
    send_data data, type: content_type, disposition: :inline
  rescue Aws::S3::Errors::NoSuchKey
    render json: { error: "not found" }, status: :not_found
  end

  private

  def set_s3_client
    @s3_client = Aws::S3::Client.new(
      endpoint: ENV.fetch('MINIO_ENDPOINT', 'http://host.docker.internal:9000'),
      access_key_id: ENV.fetch('MINIO_ACCESS_KEY', 'admin'),
      secret_access_key: ENV.fetch('MINIO_SECRET_KEY', 'password123'),
      region: "us-east-1",
      force_path_style: true
    )
    @bucket_name = "novels-bucket"
  end
end
