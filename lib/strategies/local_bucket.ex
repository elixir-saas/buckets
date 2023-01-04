defmodule Buckets.Strategies.LocalBucket do
  @behaviour Buckets.Bucket

  @impl true
  def upload(%Buckets.Upload{} = upload) do
    object_id = Ecto.UUID.generate()
    object_path = build_object_path(object_id, upload.filename)
    local_path = upload.path

    with :ok <- File.mkdir_p(Path.dirname(object_path)),
         :ok <- File.cp(local_path, object_path) do
      {:ok,
       %Buckets.Resource{
         id: object_id,
         filename: upload.filename,
         content_type: upload.content_type,
         object_path: object_path
       }}
    end
  end

  @impl true
  def download(object_id, filename) do
    File.read(build_object_path(object_id, filename))
  end

  defp build_object_path(document_id, filename) do
    Enum.join([
      System.tmp_dir!(),
      "uploader/documents/",
      document_id,
      Path.extname(filename)
    ])
  end
end
