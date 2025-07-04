defmodule Buckets.Cloud.Operations do
  @moduledoc false
  alias Buckets.Object
  alias Buckets.Location
  alias Buckets.Telemetry

  def insert(module, path, opts) when is_binary(path) do
    insert(module, Object.from_file(path), opts)
  end

  def insert(module, %Object{location: %Location.NotConfigured{}} = object, opts) do
    config = module.config()

    metadata = %{
      cloud_module: module,
      filename: object.filename,
      content_type: object.metadata[:content_type]
    }

    Telemetry.span([:buckets, :cloud, :insert], metadata, fn ->
      location_path = default_object_location(module, object, config)
      location = Location.new(location_path, config)

      insert(module, %{object | location: location}, opts)
    end)
  end

  def insert(module, %Object{} = object, _opts) do
    config = module.config()

    case Buckets.put(object, object.location.path, config) do
      {:ok, _meta} ->
        {:ok, %{object | stored?: true}}

      {:error, _reason} = error ->
        error
    end
  end

  def delete(%Object{} = object) do
    config = Location.get_config(object.location)

    metadata = %{
      filename: object.filename,
      path: object.location.path,
      adapter: config[:adapter]
    }

    Telemetry.span([:buckets, :cloud, :delete], metadata, fn ->
      case Buckets.delete(object.location.path, config) do
        {:ok, _meta} ->
          {:ok, %{object | stored?: false}}

        {:error, _reason} = error ->
          error
      end
    end)
  end

  def read(%Object{data: nil, location: %Location.NotConfigured{}}) do
    raise """
    Called `read/1` with an object that is missing a location.
    """
  end

  def read(%Object{data: {:data, data}}) do
    {:ok, data}
  end

  def read(%Object{data: {:file, path}}) do
    {:ok, File.read!(path)}
  end

  def read(%Object{} = object) do
    config = Location.get_config(object.location)

    metadata = %{
      filename: object.filename,
      path: object.location.path,
      adapter: config[:adapter]
    }

    Telemetry.span([:buckets, :cloud, :read], metadata, fn ->
      Buckets.get(object.location.path, config)
    end)
  end

  def load(_module, %Object{location: %Location.NotConfigured{}}, _opts) do
    raise """
    Called `load/1` with an object that is missing a location.
    """
  end

  def load(module, %Object{data: nil} = object, opts) do
    config = Location.get_config(object.location)

    metadata = %{
      adapter: config[:adapter],
      filename: object.filename,
      path: object.location.path,
      to: opts[:to]
    }

    Telemetry.span([:buckets, :cloud, :load], metadata, fn ->
      case Buckets.get(object.location.path, config) do
        {:ok, data} ->
          scoped_path = fn segments ->
            Path.join(segments ++ [object.uuid, object.filename])
          end

          # Get tmp_dir from cloud module
          tmp_dir = module.tmp_dir()

          object_data =
            case opts[:to] do
              nil -> {:data, data}
              :tmp -> {:file, scoped_path.([tmp_dir])}
              {:tmp, path} -> {:file, scoped_path.([tmp_dir, path])}
              path when is_binary(path) -> {:file, scoped_path.([path])}
            end

          with {:file, path} <- object_data do
            File.mkdir_p!(Path.dirname(path))
            File.write!(path, data)
          end

          {:ok, %{object | data: object_data}}

        {:error, _reason} = error ->
          error
      end
    end)
  end

  def load(module, %Object{} = object, opts) do
    case Keyword.pop(opts, :force) do
      {true, opts} -> load(module, unload(object), opts)
      _otherwise -> {:ok, object}
    end
  end

  def unload(%Object{data: nil} = object) do
    object
  end

  def unload(%Object{data: {:data, _data}} = object) do
    %{object | data: nil}
  end

  def unload(%Object{data: {:file, path}} = object) do
    File.rm!(path)
    %{object | data: nil}
  end

  def url(%Object{location: %Location.NotConfigured{}}, _opts) do
    raise """
    Unable to create a signed url for an object without a location.
    """
  end

  def url(%Object{} = object, opts) do
    config = Location.get_config(object.location)

    metadata = %{
      filename: object.filename,
      path: object.location.path,
      adapter: config[:adapter]
    }

    Telemetry.span([:buckets, :cloud, :url], metadata, fn ->
      Buckets.url(object.location.path, Keyword.merge(opts, config))
    end)
  end

  def live_upload(module, entry, opts) do
    object = Object.from_upload(entry)
    config = module.config()
    location_path = default_object_location(module, object, config)

    uploader =
      config[:uploader] ||
        raise """
        Must specifiy the :uploader config option to use `live_upload/2`.
        """

    url_opts =
      opts
      |> Keyword.merge(config)
      |> Keyword.put(:for_upload, true)

    with {:ok, signed_url} <- Buckets.url(location_path, url_opts) do
      {:ok, %{uploader: uploader, url: signed_url}}
    end
  end

  def insert!(module, object_or_path, opts) do
    case insert(module, object_or_path, opts) do
      {:ok, object} ->
        object

      {:error, reason} ->
        raise """
        Failed to put object in `insert!/2` with reason:

            #{inspect(reason)}
        """
    end
  end

  def delete!(%Object{} = object) do
    case delete(object) do
      {:ok, object} ->
        object

      {:error, reason} ->
        raise """
        Failed to delete object in `delete!/1` with reason:

            #{inspect(reason)}
        """
    end
  end

  def read!(%Object{} = object) do
    case read(object) do
      {:ok, data} ->
        data

      {:error, reason} ->
        raise """
        Failed to get object data in `read!/1` with reason:

            #{inspect(reason)}
        """
    end
  end

  def load!(module, %Object{} = object, opts) do
    case load(module, object, opts) do
      {:ok, object} ->
        object

      {:error, reason} ->
        raise """
        Failed to get object data in `load!/2` with reason:

            #{inspect(reason)}
        """
    end
  end

  def url!(object, opts) do
    case url(object, opts) do
      {:ok, signed_url} ->
        signed_url

      {:error, reason} ->
        raise """
        Failed to create signed url in `url!/2` with reason:

            #{inspect(reason)}
        """
    end
  end

  def live_upload!(module, entry, opts) do
    case live_upload(module, entry, opts) do
      {:ok, upload_config} ->
        upload_config

      {:error, reason} ->
        raise """
        Failed to create config in `live_upload!/2` with reason:

            #{inspect(reason)}
        """
    end
  end

  ## Private

  defp default_object_location(module, object, config) do
    filename_normalized = module.normalize_filename(object.filename)

    if base_path = config[:path] do
      Path.join([base_path, object.uuid, filename_normalized])
    else
      Path.join([object.uuid, filename_normalized])
    end
  end
end
