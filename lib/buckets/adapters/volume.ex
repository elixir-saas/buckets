defmodule Buckets.Adapters.Volume do
  @moduledoc """
  Adapter for local filesystem storage.

  The Volume adapter stores files on the local filesystem and is primarily intended
  for development environments. It supports signed URLs and integrates with the
  Buckets dev router for handling uploads and downloads.

  ## Configuration

      config :my_app, MyApp.Cloud,
        adapter: Buckets.Adapters.Volume,
        bucket: "tmp/buckets_volume",
        base_url: "http://localhost:4000"

  ## Required Options

  - `:bucket` - The local directory path where files will be stored
  - `:base_url` - The base URL for generating file URLs (e.g., your Phoenix app URL)

  ## Optional Options

  - `:path` - Base path within the bucket directory
  - `:endpoint` - Custom endpoint path for signed URLs (defaults to "/__buckets__")
  - `:uploader` - Uploader configuration for direct uploads

  ## Development Router Integration

  To handle local uploads and downloads in development, add the Volume routes to your router:

      # In your router.ex
      if Application.compile_env(:my_app, :dev_routes) do
        import Buckets.Router

        buckets_volume(MyApp.Cloud)
      end

  This will mount routes at `/__buckets__/:bucket/*path` for handling:
  - File uploads (PUT requests)
  - File downloads (GET requests)

  ## Signed URLs

  The Volume adapter supports signed URLs for secure file uploads and downloads:

      {:ok, object} = MyApp.Cloud.url(object, expires_in: 3600)
      # Returns object with signed URL valid for 1 hour

  ## Supervision

  This adapter does not require any supervised processes. Do not add Cloud modules
  using this adapter to your supervision tree.
  """
  @behaviour Buckets.Adapter

  @impl true
  def validate_config(config) do
    validate_result =
      Keyword.validate(config, [
        :adapter,
        :bucket,
        :path,
        :endpoint,
        :uploader,
        :base_url
      ])

    with {:ok, config} <- validate_result do
      Buckets.Adapter.validate_required(config, [:bucket])
    end
  end

  @impl true
  def put(%Buckets.Object{} = object, remote_path, config) do
    target_path = target_path(remote_path, config)

    write_data = fn
      {:data, data} -> File.write(target_path, data)
      {:file, path} -> File.cp(path, target_path)
    end

    with :ok <- File.mkdir_p(Path.dirname(target_path)),
         :ok <- write_data.(object.data) do
      {:ok, %{}}
    end
  end

  @impl true
  def get(remote_path, config) do
    File.read(target_path(remote_path, config))
  end

  @impl true
  def url(remote_path, config) do
    base_url = Keyword.fetch!(config, :base_url)

    params = %{}
    params = if config[:for_upload], do: Map.put(params, :verb, "PUT"), else: params

    bucket_encoded = Base.url_encode64(config[:bucket], padding: false)
    path = [Buckets.Router.scope(), bucket_encoded, remote_path]

    path =
      if endpoint = config[:endpoint] do
        build_signed_path(path, params, endpoint)
      else
        build_path(path, params)
      end

    location = %Buckets.Location{path: remote_path, config: config}
    {:ok, %Buckets.SignedURL{url: Path.join(base_url, path), location: location}}
  end

  @impl true
  def delete(remote_path, config) do
    File.rm(target_path(remote_path, config))
    {:ok, %{}}
  end

  ## Signing

  defp build_path(path, params) do
    path = Path.join(path)
    if params != %{}, do: "#{path}?#{URI.encode_query(params)}", else: path
  end

  defp build_signed_path(path, params, endpoint) do
    sig = hash(build_path(path, params), endpoint)
    build_path(path, Map.put(params, :sig, sig))
  end

  def verify_signed_path(path, params, endpoint) do
    case Map.pop(params, "sig") do
      {nil, _params} -> false
      {sig, params} -> hash(build_path(path, params), endpoint) == sig
    end
  end

  defp hash(binary, endpoint) do
    secret_key_base = endpoint.config(:secret_key_base)
    hash = :crypto.mac(:hmac, :sha256, secret_key_base, binary)
    Base.url_encode64(hash, padding: false)
  end

  ## Private

  defp target_path(remote_path, config) do
    Path.join(config[:bucket], remote_path)
  end
end
