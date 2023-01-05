defmodule Buckets do
  @moduledoc """
  Provides a generic interface for uploading files to buckets hosted by
  different cloud providers.
  """

  defmodule Upload do
    alias Phoenix.LiveView, as: LV

    @type t :: %__MODULE__{
            path: String.t(),
            filename: String.t(),
            content_type: String.t()
          }

    defstruct [:path, :filename, :content_type]

    def new(%Plug.Upload{} = upload) do
      %Buckets.Upload{
        path: upload.path,
        filename: upload.filename,
        content_type: upload.content_type
      }
    end

    def new({%LV.UploadEntry{done?: true} = upload, %{path: path}}) do
      %Buckets.Upload{
        path: path,
        filename: upload.client_name,
        content_type: upload.client_type
      }
    end
  end

  defmodule Object do
    @type t :: %__MODULE__{
            id: String.t(),
            filename: String.t(),
            content_type: String.t(),
            object_url: String.t(),
            object_path: String.t()
          }

    defstruct [:id, :filename, :content_type, :object_url, :object_path]
  end

  defmodule Bucket do
    @callback upload(Buckets.Upload.t(), Keyword.t()) ::
                {:ok, Buckets.Object.t()} | {:error, term}

    @callback download(object_id :: String.t(), filename :: String.t(), Keyword.t()) ::
                {:ok, binary}
  end

  def upload(%Buckets.Upload{} = upload, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.upload(upload, opts)
  end

  def download(object_id, filename, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.download(object_id, filename, opts)
  end
end
