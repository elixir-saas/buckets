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
                {:ok, binary}
  end

  defmodule Util do
    def object_id(scope) when is_binary(scope), do: scope
    def object_id(%{id: scope}) when is_binary(scope), do: scope

    def build_object_path(path, object_id, filename) do
      Path.join([path, object_id, filename]) |> String.trim_leading("/")
    end
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
end
