defmodule Buckets.Strategy.S3 do
  @behaviour Buckets.Strategy

  require Logger

  alias Buckets.Object

  @impl true
  def put(%Buckets.Object{} = object, remote_path, config) do
    req = build_req(config)
    bucket = Keyword.fetch!(config, :bucket)

    data = Object.read!(object)
    content_type = object.metadata[:content_type] || "application/octet-stream"

    case Req.put(req,
           url: "s3://#{bucket}/#{remote_path}",
           body: data,
           headers: [{"content-type", content_type}]
         ) do
      {:ok, %{status: status}} when status in 200..299 -> {:ok, %{}}
      {:ok, response} -> {:error, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get(remote_path, config) do
    req = build_req(config)
    bucket = Keyword.fetch!(config, :bucket)

    case Req.get(req, url: "s3://#{bucket}/#{remote_path}") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, response} ->
        {:error, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def delete(remote_path, config) do
    req = build_req(config)
    bucket = Keyword.fetch!(config, :bucket)

    case Req.delete(req, url: "s3://#{bucket}/#{remote_path}") do
      {:ok, %{status: status}} when status in 200..299 -> {:ok, %{}}
      {:ok, response} -> {:error, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def url(remote_path, config) do
    bucket = Keyword.fetch!(config, :bucket)

    opts =
      if config[:for_upload] == true do
        [method: :put, expires: 900]
      else
        [method: :get, expires: 60]
      end

    presign_opts = [
      bucket: bucket,
      key: remote_path,
      access_key_id: Keyword.fetch!(config, :access_key_id),
      secret_access_key: Keyword.fetch!(config, :secret_access_key),
      region: Keyword.fetch!(config, :region)
    ]

    presign_opts =
      if endpoint_url = config[:endpoint_url] do
        Keyword.put(presign_opts, :endpoint_url, endpoint_url)
      else
        presign_opts
      end

    presign_opts =
      presign_opts
      |> Keyword.merge(opts)
      |> Keyword.merge(config[:s3_signed_url] || [])

    signed_url = ReqS3.presign_url(presign_opts)

    location = %Buckets.Location{path: remote_path, config: config}
    {:ok, %Buckets.SignedURL{url: signed_url, location: location}}
  end

  ## Private

  defp build_req(config) do
    opts = [
      aws_sigv4: [
        access_key_id: Keyword.fetch!(config, :access_key_id),
        secret_access_key: Keyword.fetch!(config, :secret_access_key),
        region: Keyword.fetch!(config, :region)
      ]
    ]

    # Add endpoint URL if provided (for S3-compatible services)
    opts =
      if endpoint_url = config[:endpoint_url] do
        Keyword.put(opts, :aws_endpoint_url_s3, endpoint_url)
      else
        opts
      end

    Req.new() |> ReqS3.attach(opts)
  end
end
