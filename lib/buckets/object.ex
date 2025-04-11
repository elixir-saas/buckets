defmodule Buckets.Object do
  alias Phoenix.LiveView, as: LV

  @type t :: %__MODULE__{
          uuid: String.t(),
          filename: String.t(),
          data: nil | {:data, binary()} | {:file, String.t()},
          metadata: map(),
          location: Buckets.Location.t() | %Buckets.Location.NotConfigured{},
          stored?: boolean()
        }

  defstruct [:uuid, :filename, :data, :metadata, :location, :stored?]

  def read(%__MODULE__{} = object) do
    case object.data do
      nil -> {:error, :not_loaded}
      {:data, data} -> {:ok, data}
      {:file, path} -> File.read(path)
    end
  end

  def read!(%__MODULE__{} = object) do
    case read(object) do
      {:ok, data} ->
        data

      {:error, :not_loaded} ->
        raise """
        Called `read!/1` with object that does not have data loaded.
        """

      {:error, reason} ->
        raise """
        Failed to access file at the specified path in `read!/1`:

            #{to_string(:file.format_error(reason))}
        """
    end
  end

  def new(uuid, filename, opts) do
    %__MODULE__{
      uuid: uuid,
      filename: filename,
      data: nil,
      metadata: Keyword.get(opts, :metadata, %{}),
      location: Keyword.get(opts, :location, %Buckets.Location.NotConfigured{}),
      stored?: Keyword.has_key?(opts, :location)
    }
  end

  def from_file(path) do
    if not File.exists?(path) do
      raise """
      Called `from_file/1` with a path to a non-existent file.
      """
    end

    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      filename: Path.basename(path),
      data: {:file, path},
      metadata: %{
        content_type: MIME.from_path(path),
        content_size: Buckets.Util.size(path)
      },
      location: %Buckets.Location.NotConfigured{},
      stored?: false
    }
  end

  def from_upload(%Plug.Upload{} = upload) do
    %__MODULE__{
      uuid: Ecto.UUID.generate(),
      filename: upload.filename,
      data: {:file, upload.path},
      metadata: %{
        content_type: upload.content_type || MIME.from_path(upload.path),
        content_size: Buckets.Util.size(upload.path)
      },
      location: %Buckets.Location.NotConfigured{},
      stored?: false
    }
  end

  def from_upload({%LV.UploadEntry{} = upload, meta}) do
    if not upload.done? do
      raise """
      Called `from_upload/1` with a `LiveView.UploadEntry` struct that was not done uploading.
      """
    end

    {data, content_type, content_size} =
      case meta do
        %{path: path} -> {{:file, path}, MIME.from_path(path), Buckets.Util.size(path)}
        _otherwise -> {nil, upload.client_type, upload.client_size}
      end

    location =
      case meta do
        %{url: %Buckets.SignedURL{location: location}} -> location
        _otherwise -> %Buckets.Location.NotConfigured{}
      end

    %__MODULE__{
      uuid: upload.uuid,
      filename: upload.client_name,
      data: data,
      metadata: %{
        content_type: content_type,
        content_size: content_size
      },
      location: location,
      stored?: location != %Buckets.Location.NotConfigured{}
    }
  end
end
