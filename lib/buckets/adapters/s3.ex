defmodule Buckets.Adapters.S3 do
  @moduledoc """
  Adapter for Amazon S3 and S3-compatible storage services.

  This adapter supports multiple S3-compatible providers through the `:provider` option:
  - `:aws` (default) - Amazon S3
  - `:cloudflare` - Cloudflare R2
  - `:digitalocean` - DigitalOcean Spaces
  - `:tigris` - Tigris

  ## Configuration

  ### Amazon S3 (default)

      config :my_app, MyApp.Cloud,
        adapter: Buckets.Adapters.S3,
        bucket: "my-bucket",
        region: "us-east-1",
        access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")

  ### Cloudflare R2

      config :my_app, MyApp.Cloud,
        adapter: Buckets.Adapters.S3,
        provider: :cloudflare,
        bucket: "my-bucket",
        endpoint_url: "https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com",
        access_key_id: System.fetch_env!("R2_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("R2_SECRET_ACCESS_KEY")

  Note: Cloudflare R2 automatically uses `region: "auto"`.

  ### DigitalOcean Spaces

      config :my_app, MyApp.Cloud,
        adapter: Buckets.Adapters.S3,
        provider: :digitalocean,
        bucket: "my-bucket",
        access_key_id: System.fetch_env!("SPACES_ACCESS_KEY"),
        secret_access_key: System.fetch_env!("SPACES_SECRET_KEY")

  Note: DigitalOcean Spaces defaults to NYC3 region and endpoint. Override with:

      config :my_app, MyApp.Cloud,
        adapter: Buckets.Adapters.S3,
        provider: :digitalocean,
        bucket: "my-bucket",
        region: "sfo3",
        endpoint_url: "https://sfo3.digitaloceanspaces.com",
        access_key_id: System.fetch_env!("SPACES_ACCESS_KEY"),
        secret_access_key: System.fetch_env!("SPACES_SECRET_KEY")

  ### Tigris

      config :my_app, MyApp.Cloud,
        adapter: Buckets.Adapters.S3,
        provider: :tigris,
        bucket: "my-bucket",
        region: "auto",
        access_key_id: System.fetch_env!("TIGRIS_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("TIGRIS_SECRET_ACCESS_KEY")

  Note: Tigris automatically uses the endpoint `https://fly.storage.tigris.dev`.

  ## Required Options

  - `:bucket` - The S3 bucket name
  - `:access_key_id` - AWS access key ID or equivalent
  - `:secret_access_key` - AWS secret access key or equivalent
  - `:region` - AWS region (defaults to "auto" for some providers)
  - `:endpoint_url` - Required for non-AWS providers

  ## Optional Options

  - `:provider` - The S3-compatible provider (defaults to `:aws`)
  - `:path` - Base path within the bucket
  - `:uploader` - Uploader configuration for direct uploads

  ## Supervision

  This adapter does not require any supervised processes. You do not need to add Cloud modules
  using this adapter to your supervision tree.
  """
  @behaviour Buckets.Adapter

  require Logger

  alias Buckets.Object

  @impl true
  def validate_config(config) do
    validate_result =
      Keyword.validate(config, [
        :adapter,
        :bucket,
        :path,
        :uploader,
        :endpoint_url,
        :access_key_id,
        :secret_access_key,
        provider: :aws,
        region: "auto"
      ])

    with {:ok, config} <- validate_result do
      provider_defaults =
        case Keyword.fetch!(config, :provider) do
          :aws -> []
          :cloudflare -> [region: "auto"]
          :digitalocean -> [endpoint_url: "https://nyc3.digitaloceanspaces.com", region: "nyc3"]
          :tigris -> [endpoint_url: "https://fly.storage.tigris.dev"]
          provider -> raise "Unknown S3 provider: #{inspect(provider)}"
        end

      config = Keyword.merge(provider_defaults, config)

      Buckets.Adapter.validate_required(config, [
        :bucket,
        :access_key_id,
        :secret_access_key,
        :region,
        if(config[:provider] != :aws, do: :endpoint_url)
      ])
    end
  end

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
  def copy(source_path, destination_path, config) do
    req = build_req(config)
    bucket = Keyword.fetch!(config, :bucket)

    case Req.put(req,
           url: "s3://#{bucket}/#{destination_path}",
           headers: [{"x-amz-copy-source", "/#{bucket}/#{source_path}"}]
         ) do
      {:ok, %{status: status}} when status in 200..299 -> {:ok, %{}}
      {:ok, response} -> {:error, response}
      {:error, reason} -> {:error, reason}
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
