defmodule Buckets.Cloud do
  defmacro __using__(opts) do
    otp_app = opts[:otp_app]
    default_location = opts[:default_location]

    quote do
      def read(%Buckets.ObjectV2{data: nil, location: %Buckets.Location.NotConfigured{}}) do
        raise """
        Called `read/1` with an object that is missing a location.
        """
      end

      def read(%Buckets.ObjectV2{data: {:data, data}}) do
        {:ok, data}
      end

      def read(%Buckets.ObjectV2{data: {:file, path}}) do
        {:ok, File.read!(path)}
      end

      def read(%Buckets.ObjectV2{} = object) do
        object.location.config[:strategy].get_v2(object)
      end

      def read!(object) do
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

      def load(object, opts \\ [])

      def load(%Buckets.ObjectV2{location: %Buckets.Location.NotConfigured{}}, _opts) do
        raise """
        Called `load/1` with an object that is missing a location.
        """
      end

      def load(%Buckets.ObjectV2{data: nil} = object, opts) do
        case object.location.config[:strategy].get_v2(object) do
          {:ok, data} ->
            scoped_path = fn segments ->
              Path.join(segments ++ [object.uuid, object.filename])
            end

            object_data =
              case opts[:to] do
                nil -> {:data, data}
                :tmp -> {:file, scoped_path.([tmp_dir()])}
                {:tmp, path} -> {:file, scoped_path.([tmp_dir(), path])}
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
      end

      def load(%Buckets.ObjectV2{} = object, opts) do
        case Keyword.pop(opts, :force) do
          {true, opts} -> load(unload(object), opts)
          _otherwise -> {:ok, object}
        end
      end

      def load!(object, opts \\ []) do
        case load(object, opts) do
          {:ok, object} ->
            object

          {:error, reason} ->
            raise """
            Failed to get object data in `load!/2` with reason:

                #{inspect(reason)}
            """
        end
      end

      def unload(%Buckets.ObjectV2{data: nil} = object) do
        object
      end

      def unload(%Buckets.ObjectV2{data: {:data, _data}} = object) do
        %{object | data: nil}
      end

      def unload(%Buckets.ObjectV2{data: {:file, path}} = object) do
        File.rm!(path)
        %{object | data: nil}
      end

      def insert(object_or_path, opts \\ [])

      def insert(path, opts) when is_binary(path) do
        insert(Buckets.ObjectV2.from_file(path), opts)
      end

      def insert(%Buckets.ObjectV2{location: %Buckets.Location.NotConfigured{}} = object, opts) do
        {location, opts} = Keyword.pop(opts, :location, unquote(default_location))

        location_config = config_for(location)
        filename_normalized = normalize_filename(unquote(default_location), object.filename)

        location_path =
          if base_path = location_config[:path] do
            Path.join([base_path, object.uuid, filename_normalized])
          else
            Path.join([object.uuid, filename_normalized])
          end

        location = Buckets.Location.new(location_path, location_config)
        insert(%{object | location: location}, opts)
      end

      def insert(%Buckets.ObjectV2{} = object, _opts) do
        case object.location.config[:strategy].put_v2(object) do
          {:ok, _meta} ->
            {:ok, %{object | stored?: true}}

          {:error, _reason} = error ->
            error
        end
      end

      def insert!(object_or_path, opts \\ []) do
        case insert(object_or_path, opts) do
          {:ok, object} ->
            object

          {:error, reason} ->
            raise """
            Failed to put object in `insert!/2` with reason:

                #{inspect(reason)}
            """
        end
      end

      def delete(object) do
        case object.location.config[:strategy].delete_v2(object.location) do
          {:ok, _meta} ->
            {:ok, %{object | stored?: false}}

          {:error, _reason} = error ->
            error
        end
      end

      def delete!(object) do
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

      ## Overridable

      def tmp_dir() do
        System.tmp_dir!()
      end

      def normalize_filename(_location, filename) do
        Buckets.Util.normalize_filename(filename)
      end

      defoverridable tmp_dir: 0, normalize_filename: 2

      ## Config

      def config_for(:default), do: config_for(unquote(default_location))
      def config_for(location), do: Keyword.fetch!(config(:locations), location)

      defp config(key), do: Keyword.fetch!(config(), key)
      defp config(), do: Application.fetch_env!(unquote(otp_app), __MODULE__)
    end
  end
end
