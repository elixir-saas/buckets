defmodule Buckets do
  @moduledoc """
  Provides a generic interface for uploading files to buckets hosted by
  different cloud providers.
  """

  defmodule Upload do
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

  defmodule Object do
    @type t :: %__MODULE__{
            filename: String.t(),
            content_type: String.t(),
            object_url: String.t(),
            object_path: String.t()
          }

    defstruct [:filename, :content_type, :object_url, :object_path]
  end

  defmodule Bucket do
    @type scope() :: binary() | %{id: binary()}

    @callback put(Buckets.Upload.t(), scope(), Keyword.t()) ::
                {:ok, Buckets.Object.t()} | {:error, term}

    @callback get(filename :: String.t(), scope(), Keyword.t()) ::
                {:ok, binary}

    @callback url(filename :: String.t(), scope(), Keyword.t()) ::
                {:ok, Buckets.SignedURL.t()}

    @callback delete(filename :: String.t(), scope(), Keyword.t()) ::
                :ok
  end

  def put(%Buckets.Upload{} = upload, scope, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.put(upload, scope, opts)
  end

  def get(filename, scope, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.get(filename, scope, opts)
  end

  def url(filename, scope, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.url(filename, scope, opts)
  end

  def delete(filename, scope, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.delete(filename, scope, opts)
  end
end
