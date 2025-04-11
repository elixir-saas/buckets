defmodule Buckets.Strategy.Volume do
  @behaviour Buckets.Strategy

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

    query = %{
      path: remote_path,
      bucket: config[:bucket]
    }

    url = "#{base_url}/__buckets__/volume?#{URI.encode_query(query)}"

    {:ok, %Buckets.SignedURL{path: remote_path, url: url}}
  end

  @impl true
  def delete(remote_path, config) do
    File.rm(target_path(remote_path, config))
    {:ok, %{}}
  end

  ## Private

  defp target_path(remote_path, config) do
    Path.join(config[:bucket], remote_path)
  end
end
