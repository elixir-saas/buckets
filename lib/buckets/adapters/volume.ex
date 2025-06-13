defmodule Buckets.Adapters.Volume do
  @behaviour Buckets.Adapter

  @impl true
  def validate_config(config) do
    validate_result =
      Keyword.validate(config, [
        :adapter,
        :bucket,
        :path,
        :endpoint,
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

    bucket_encoded = URI.encode(config[:bucket], &URI.char_unreserved?/1)
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
