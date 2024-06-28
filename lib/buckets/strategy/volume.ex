defmodule Buckets.Strategy.Volume do
  @behaviour Buckets.Bucket

  alias Buckets.Util

  @impl true
  def put(%Buckets.Upload{} = upload, scope, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    object_path = Util.build_object_path(upload.filename, scope, opts)
    object_bucket_path = Path.join(bucket, object_path)

    with :ok <- File.mkdir_p(Path.dirname(object_bucket_path)),
         :ok <- File.cp(upload.path, object_bucket_path) do
      {:ok,
       %Buckets.Object{
         filename: upload.filename,
         content_type: upload.content_type,
         object_url: "file://" <> object_bucket_path,
         object_path: object_path
       }}
    end
  end

  @impl true
  def get(filename, scope, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    object_path = Util.build_object_path(filename, scope, opts)

    File.read(Path.join(bucket, object_path))
  end

  @impl true
  def url(filename, scope, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    base_url = Keyword.fetch!(opts, :base_url)
    object_path = Util.build_object_path(filename, scope, opts)

    query = %{path: object_path, bucket: bucket}
    url = "#{base_url}/__buckets__/volume?#{URI.encode_query(query)}"

    {:ok, %Buckets.SignedURL{path: object_path, filename: filename, url: url}}
  end

  @impl true
  def delete(filename, scope, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    object_path = Util.build_object_path(filename, scope, opts)

    File.rm(Path.join(bucket, object_path))
    :ok
  end
end
