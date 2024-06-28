defmodule Buckets.Upload do
  alias Phoenix.LiveView, as: LV

  @type t :: %__MODULE__{
          uuid: String.t(),
          path: String.t(),
          filename: String.t(),
          content_type: String.t(),
          content_size: String.t()
        }

  defstruct [:uuid, :path, :filename, :content_type, :content_size]

  def new(%Plug.Upload{} = upload) do
    %Buckets.Upload{
      uuid: Ecto.UUID.generate(),
      path: upload.path,
      filename: upload.filename,
      content_type: upload.content_type,
      content_size: Buckets.Util.size(upload.path)
    }
  end

  def new({%LV.UploadEntry{done?: true} = upload, meta}) do
    %Buckets.Upload{
      uuid: upload.uuid,
      path: meta[:path],
      filename: upload.client_name,
      content_type: upload.client_type,
      content_size: if(p = meta[:path], do: Buckets.Util.size(p), else: upload.client_size)
    }
  end
end
