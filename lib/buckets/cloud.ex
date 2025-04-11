defmodule Buckets.Cloud do
  @moduledoc """
  Defines a cloud.

  A cloud manages the movement of files and data between your application and
  remote buckets for persistent storage.

  When used, it expects `:otp_app` and `:default_location` as options:

      defmodule MyApp.Cloud do
        use Buckets.Cloud,
          otp_app: :my_app,
          default_location: :local
      end

  Additional configuration is fetched from the application config, using a
  combination of `:otp_app` and the module that you defined. You may configure
  many "locations" in your config, for setting up multi-cloud support:

        config :my_app, MyApp.Cloud,
          locations: [
            local: [
              strategy: Buckets.Strategy.Volume,
              # configure this strategy...
            ],
            gcs: [
              strategy: Buckets.Strategy.GCS,
              # configure this strategy...
            ],
            us_east_1: [
              strategy: Buckets.Strategy.S3,
              # configure this strategy...
            ]
          ]

  You may also specify config dynamically at runtime, using the `:config` opt
  where it is supported.

  When building a multi-cloud application and persisting uploaded objects to a
  database, you should take care to store some indicator of the location config that
  was used to insert a particular object. Otherwise, you won't know how to fetch
  data for or manage that object the next time it is accessed.

  Similarly, if you are building a dynamic-cloud application (say, so that your users
  can specify their own clouds for your application to use), you should store the
  configuration provided by the user. As objects are inserted to the cloud and stored
  in your database, add a mapping between the object and the user-provided config. If
  this config is ever deleted, objects managed by it will become inaccessible. Keep this
  in mind as you build features to let users update or delete their config.
  """

  @doc """
  Inserts a `Buckets.Object` or a file from a path into a bucket.
  """
  @callback insert(
              object_or_path :: Buckets.Object.t() | String.t(),
              opts :: Keyword.t()
            ) :: {:ok, Buckets.Object.t()} | {:error, term()}

  @doc """
  Deletes a `Buckets.Object` permanently.
  """
  @callback delete(object :: Buckets.Object.t()) :: {:ok, Buckets.Object.t()} | {:error, term()}

  @doc """
  Reads the data for `Buckets.Object`, preferring local data first and fetching from
  the remote bucket if needed.
  """
  @callback read(object :: Buckets.Object.t()) :: {:ok, binary()} | {:error, term()}

  @doc """
  Loads the data for a `Buckets.Object`, placing it in memory by default. It will load data
  lazily, doing nothing if data is already present.

  ## Options

      * `:to` - A location to store the loaded data to on disk, if this is preferred over
        loading to memory. May be a path, `:tmp` (to load to the configured tmp dir), or
        `{:tmp, path}` (to load to a path in the configured tmp dir).
      * `:force` - If data is already present, first unload it with `c:unload/1` before loading
        new data. Warning: if data is stored in a file, it will be deleted.
  """
  @callback load(
              object :: Buckets.Object.t(),
              opts :: Keyword.t()
            ) :: {:ok, Buckets.Object.t()} | {:error, term()}

  @doc """
  Unloads the data for a `Buckets.Object`. If the data is stored in a local file, the file will
  be deleted.
  """
  @callback unload(object :: Buckets.Object.t()) :: Buckets.Object.t()

  @doc """
  Returns a map to be used as configuration for a LiveView live upload. The configuration
  contains a signed URL that permits the upload to a remote bucket. Requires that an `:uploader`
  is configured for the location that the file is being uploaded to.
  """
  @callback live_upload(
              entry :: Phoenix.LiveView.UploadEntry.t(),
              opts :: Keyword.t()
            ) :: {:ok, map()} | {:error, term()}

  @doc """
  Same as `c:insert/2` but returns the object or raises if there is an error.
  """
  @callback insert!(
              object_or_path :: Buckets.Object.t() | String.t(),
              opts :: Keyword.t()
            ) :: Buckets.Object.t()

  @doc """
  Same as `c:delete/1` but returns the object or raises if there is an error.
  """
  @callback delete!(object :: Buckets.Object.t()) :: Buckets.Object.t()

  @doc """
  Same as `c:read/1` but returns the data or raises if there is an error.
  """
  @callback read!(object :: Buckets.Object.t()) :: binary()

  @doc """
  Same as `c:load/1` but returns the object or raises if there is an error.
  """
  @callback load!(object :: Buckets.Object.t(), opts :: Keyword.t()) :: Buckets.Object.t()

  @doc """
  Same as `c:live_upload/1` but returns the upload config or raises if there is an error.
  """
  @callback live_upload!(
              entry :: Phoenix.LiveView.UploadEntry.t(),
              opts :: Keyword.t()
            ) :: map()

  @doc """
  An overridable function that specifies the temporary directory in which objects are stored.

  Defaults to `System.tmp_dir!()`.
  """
  @callback tmp_dir() :: String.t()

  @doc """
  An overridable function that processes filenames before encoding them in a remote path.

  By default, replaces whitespace with `"_"` and removes all non-alphanumeric characters.
  """
  @callback normalize_filename(filename :: String.t()) :: String.t()

  defmacro __using__(opts) do
    otp_app = opts[:otp_app]
    default_location = opts[:default_location]

    quote do
      @behaviour Buckets.Cloud

      def insert(object_or_path, opts \\ []) do
        Buckets.Cloud.Operations.insert(__MODULE__, object_or_path, opts)
      end

      def delete(object) do
        Buckets.Cloud.Operations.delete(object)
      end

      def read(object) do
        Buckets.Cloud.Operations.read(object)
      end

      def load(object, opts \\ []) do
        Buckets.Cloud.Operations.load(__MODULE__, object, opts)
      end

      def unload(object) do
        Buckets.Cloud.Operations.unload(object)
      end

      def live_upload(entry, opts \\ []) do
        Buckets.Cloud.Operations.live_upload(__MODULE__, entry, opts)
      end

      def insert!(object_or_path, opts \\ []) do
        Buckets.Cloud.Operations.insert!(__MODULE__, object_or_path, opts)
      end

      def delete!(object) do
        Buckets.Cloud.Operations.delete!(object)
      end

      def read!(object) do
        Buckets.Cloud.Operations.read!(object)
      end

      def load!(object, opts \\ []) do
        Buckets.Cloud.Operations.load!(__MODULE__, object, opts)
      end

      def live_upload!(entry, opts \\ []) do
        Buckets.Cloud.Operations.live_upload!(__MODULE__, entry, opts)
      end

      ## Overridable

      def tmp_dir() do
        System.tmp_dir!()
      end

      def normalize_filename(filename) do
        Buckets.Util.normalize_filename(filename)
      end

      defoverridable tmp_dir: 0, normalize_filename: 1

      ## Config

      def config_for(:default), do: config_for(unquote(default_location))
      def config_for(location), do: Keyword.fetch!(config(:locations), location)

      defp config(key), do: Keyword.fetch!(config(), key)
      defp config(), do: Application.fetch_env!(unquote(otp_app), __MODULE__)
    end
  end
end
