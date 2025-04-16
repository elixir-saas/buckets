defmodule Buckets.Strategy.S3 do
  @behaviour Buckets.Strategy

  require Logger

  alias Buckets.Object

  @impl true
  def put(%Buckets.Object{} = object, remote_path, config) do
    region = Keyword.fetch!(config, :region)
    bucket = Keyword.fetch!(config, :bucket)

    data = Object.read!(object)

    content_type = object.metadata[:content_type] || "application/octet-stream"

    case ExAws.S3.put_object(bucket, remote_path, data, content_type: content_type)
         |> ExAws.request(region: region) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get(remote_path, config) do
    region = Keyword.fetch!(config, :region)
    bucket = Keyword.fetch!(config, :bucket)

    case ExAws.S3.get_object(bucket, remote_path) |> ExAws.request(region: region) do
      {:ok, response} ->
        {:ok, response.body}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def delete(remote_path, config) do
    region = Keyword.fetch!(config, :region)
    bucket = Keyword.fetch!(config, :bucket)

    case ExAws.S3.delete_object(bucket, remote_path) |> ExAws.request(region: region) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def url(remote_path, config) do
    if config[:for_upload] == true and config[:s3_signed_url] == nil do
      Logger.warning("""
      Whan generating a S3 signed URL for direct upload, always include
      a `:s3_signed_url` option, for example:

          gcs_signed_url: [method: :put, expires: 900]

      Otherwise, S3 will reject the PUT request to store the file on upload.
      """)
    end

    region = Keyword.fetch!(config, :region)
    bucket = Keyword.fetch!(config, :bucket)

    signed_url_config = Keyword.get(config, :s3_signed_url, [])

    case ExAws.S3.presigned_url(
           ExAws.Config.new(:s3, region: region),
           Keyword.get(signed_url_config, :method, :get),
           bucket,
           remote_path,
           Keyword.put_new(signed_url_config, :expires_in, 3600)
         ) do
      {:ok, signed_url} ->
        location = %Buckets.Location{path: remote_path, config: config}
        {:ok, %Buckets.SignedURL{url: signed_url, location: location}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # def headers(remote_path, config) do
  #   region = Keyword.fetch!(config, :region)
  #   bucket = Keyword.fetch!(config, :bucket)

  #   case ExAws.S3.head_object(bucket, remote_path) |> ExAws.request(region: region) do
  #     {:ok, response} ->
  #       headers = Map.new(response.headers)

  #       {:ok,
  #        %{
  #          content_size: headers["Content-Length"],
  #          content_type: headers["Content-Type"]
  #        }}

  #     {:error, {:http_error, 404, _}} ->
  #       {:error, :not_found}

  #     {:error, reason} ->
  #       {:error, reason}
  #   end
  # end
end
