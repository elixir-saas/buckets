defmodule Buckets.Object do
  @moduledoc """
  Represents a file object in the Buckets storage system.

  An Object encapsulates file data, metadata, and location information. Objects
  can exist in various states:

  ## Object States

  1. **Local only** - Created from a file or upload, not yet stored remotely
     - `stored?: false`
     - `location: %Buckets.Location.NotConfigured{}`
     - `data: {:file, path}` or `{:data, binary}`

  2. **Stored remotely** - Uploaded to cloud storage
     - `stored?: true`
     - `location: %Buckets.Location{}`
     - `data: nil` (unless loaded)

  3. **Loaded** - Remote object with data fetched
     - `stored?: true`
     - `location: %Buckets.Location{}`
     - `data: {:file, path}` or `{:data, binary}`

  ## Creating Objects

  Objects can be created from:
  - Files on disk: `from_file/1`
  - Plug uploads: `from_upload/1` with `%Plug.Upload{}`
  - LiveView uploads: `from_upload/1` with `%Phoenix.LiveView.UploadEntry{}`
  - Manually: `new/3`

  ## Metadata

  Objects store metadata including:
  - `:content_type` - MIME type of the file
  - `:content_size` - Size in bytes
  - Custom metadata can be added as needed

  ## Example Usage

      # Create from file
      object = Buckets.Object.from_file("/path/to/document.pdf")

      # Upload to storage
      {:ok, stored} = MyApp.Cloud.insert(object)

      # Read data from stored object
      {:ok, data} = MyApp.Cloud.read(stored)

      # Load remote object data
      {:ok, loaded} = MyApp.Cloud.load(stored)
      {:ok, data} = Buckets.Object.read(loaded)
  """
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

  @doc """
  Reads the data from an object.

  Returns `{:ok, data}` if the object has data loaded, either in memory
  or from a file. Returns `{:error, :not_loaded}` if no data is available.

  ## Examples

      # Object with data in memory
      {:ok, binary_data} = Buckets.Object.read(object)

      # Object without loaded data
      {:error, :not_loaded} = Buckets.Object.read(remote_object)

  ## Note

  For remote objects without loaded data, use `Cloud.load/2` first to fetch
  the data from storage.
  """
  def read(%__MODULE__{} = object) do
    case object.data do
      nil -> {:error, :not_loaded}
      {:data, data} -> {:ok, data}
      {:file, path} -> File.read(path)
    end
  end

  @doc """
  Reads the data from an object, raising on error.

  Same as `read/1` but raises an exception if the data cannot be read.

  ## Raises

  - Raises if the object has no data loaded
  - Raises if the file cannot be read from disk

  ## Examples

      # Success case
      binary_data = Buckets.Object.read!(object)

      # Raises for unloaded object
      Buckets.Object.read!(remote_object)
      # ** (RuntimeError) Called `read!/1` with object that does not have data loaded.
  """
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

  @doc """
  Creates a new Object with the given UUID, filename, and options.

  ## Parameters

  - `uuid` - Unique identifier for the object
  - `filename` - Original filename
  - `opts` - Keyword list of options:
    - `:location` - Either `{path, config}` tuple or `%Buckets.Location{}` struct
    - `:metadata` - Map of metadata (defaults to `%{}`)

  ## Examples

      # Basic object
      object = Buckets.Object.new("123", "document.pdf", [])

      # With location
      object = Buckets.Object.new("123", "document.pdf",
        location: {"uploads/123/document.pdf", MyApp.Cloud}
      )

      # With metadata
      object = Buckets.Object.new("123", "document.pdf",
        metadata: %{content_type: "application/pdf", author: "John"}
      )
  """
  def new(uuid, filename, opts) do
    location =
      case opts[:location] do
        {path, config} -> Buckets.Location.new(path, config)
        %Buckets.Location{} = location -> location
        _otherwise -> %Buckets.Location.NotConfigured{}
      end

    %__MODULE__{
      uuid: uuid,
      filename: filename,
      data: nil,
      metadata: Keyword.get(opts, :metadata, %{}),
      location: location,
      stored?: location != %Buckets.Location.NotConfigured{}
    }
  end

  @doc """
  Creates an Object from a file on disk.

  Automatically generates a UUID and extracts metadata including content type
  (from file extension) and content size.

  ## Parameters

  - `path` - Path to the file on disk

  ## Raises

  Raises if the file does not exist.

  ## Examples

      object = Buckets.Object.from_file("/tmp/upload.pdf")
      # %Buckets.Object{
      #   uuid: "generated-uuid",
      #   filename: "upload.pdf",
      #   data: {:file, "/tmp/upload.pdf"},
      #   metadata: %{
      #     content_type: "application/pdf",
      #     content_size: 12345
      #   },
      #   stored?: false
      # }
  """
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

  @doc """
  Creates an Object from various upload types.

  This function has multiple clauses to handle different upload scenarios:

  ## Plug.Upload

  Creates an Object from a `%Plug.Upload{}` struct (Phoenix controller uploads).
  Automatically extracts metadata including content type and size.

      def create(conn, %{"file" => upload}) do
        object = Buckets.Object.from_upload(upload)
        {:ok, stored} = MyApp.Cloud.insert(object)
      end

  ## LiveView UploadEntry (incomplete)

  Creates an Object from a `%Phoenix.LiveView.UploadEntry{}` that is not yet complete.
  Used for generating signed URLs for direct uploads.

      # In LiveView for generating upload URLs
      object = Buckets.Object.from_upload(entry)
      {:ok, config} = MyApp.Cloud.live_upload(entry)

  Raises if called with a completed upload entry without metadata.

  ## LiveView UploadEntry (completed)

  Creates an Object from a completed upload with metadata tuple `{entry, meta}`.
  The metadata typically includes the uploaded file path and/or signed URL.

      # After LiveView upload completes
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
        object = Buckets.Object.from_upload({entry, %{path: path}})
        {:ok, object}
      end)

  Raises if called with an incomplete upload entry.
  """
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

  def from_upload(%LV.UploadEntry{} = upload) do
    if upload.done? do
      raise """
      Called `from_upload/1` with a `LiveView.UploadEntry` struct that was done uploading, but
      without any metadata.

      For finished uploads, provide both in a tuple: `{%UploadEntry{}, meta}`.
      """
    end

    %__MODULE__{
      uuid: upload.uuid,
      filename: upload.client_name,
      data: nil,
      metadata: %{},
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
        %{path: path} ->
          content_type = upload.client_type || MIME.from_path(path)
          {{:file, path}, content_type, Buckets.Util.size(path)}

        _otherwise ->
          {nil, upload.client_type, upload.client_size}
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
