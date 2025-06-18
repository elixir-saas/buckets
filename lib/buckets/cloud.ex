defmodule Buckets.Cloud do
  @moduledoc """
  Defines a cloud.

  A cloud manages the movement of files and data between your application and
  a remote bucket for persistent storage.

  When used, it expects `:otp_app` as an option:

      defmodule MyApp.Cloud do
        use Buckets.Cloud,
          otp_app: :my_app
      end

  Configuration is fetched from the application config, using a combination of
  `:otp_app` and the module that you defined:

      config :my_app, MyApp.Cloud,
        adapter: Buckets.Adapters.Volume,
        bucket: "tmp/buckets_volume",
        base_url: "http://localhost:4000"

  Each Cloud module corresponds to a single storage backend, similar to how
  Ecto.Repo modules correspond to a single database. For multi-cloud applications,
  define multiple Cloud modules:

      defmodule MyApp.VolumeCloud do
        use Buckets.Cloud, otp_app: :my_app
      end

      defmodule MyApp.GCSCloud do
        use Buckets.Cloud, otp_app: :my_app
      end

      defmodule MyApp.S3Cloud do
        use Buckets.Cloud, otp_app: :my_app
      end

  You may also specify config dynamically at runtime, using the `:config` opt
  where it is supported.

  ## Supervision

  Cloud modules start a supervisor that manages any background processes required 
  by the configured adapter. Some adapters (like GCS) need authentication servers,
  while others (like Volume, S3) don't need any supervised processes.

  **Only add Cloud modules to your supervision tree if they need background processes.**
  If you add a Cloud module that doesn't need supervision (Volume, S3), you'll see
  a warning message suggesting you remove it to avoid unnecessary overhead.

      # Only needed for adapters that require background processes (like GCS)
      children = [
        MyApp.GCSCloud  # GCS needs auth servers
        # MyApp.VolumeCloud - Not needed, would show warning
        # MyApp.S3Cloud - Not needed, would show warning
      ]

  ## Dynamic Configuration

  For multi-tenant applications where cloud configurations are determined at runtime,
  every Cloud module supports dynamic configuration using the process dictionary,
  similar to Ecto's dynamic repositories.

  ### Usage

  There are two ways to use dynamic configuration:

  #### 1. Scoped Configuration (like Ecto transactions)

  Use `with_config/2` for temporary configuration:

      # Define the runtime configuration
      config = [
        adapter: Buckets.Adapters.S3,
        bucket: "user-bucket",
        access_key_id: "AKIA...",
        secret_access_key: "secret...",
        region: "us-east-1"
      ]

      # Execute operations with the dynamic config
      {:ok, object} = MyApp.Cloud.with_config(config, fn ->
        MyApp.Cloud.insert("file.pdf")
        MyApp.Cloud.insert("another.pdf")  # Same config
      end)

  #### 2. Process-Local Configuration (like Ecto.Repo.put_dynamic_repo)

  Use `put_dynamic_config/1` for persistent configuration in the current process:

      # Set dynamic config for this process
      :ok = MyApp.Cloud.put_dynamic_config([
        adapter: Buckets.Adapters.GCS,
        bucket: "tenant-specific-bucket",
        service_account_credentials: tenant.credentials
      ])

      # All subsequent operations use the dynamic config
      {:ok, object1} = MyApp.Cloud.insert("file1.pdf")
      {:ok, object2} = MyApp.Cloud.insert("file2.pdf")

  ### Auth Server Management

  Auth servers (for GCS) are automatically started and cached per-process as needed.
  You don't need any special configuration or supervision setup for dynamic clouds.
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
  Returns a SignedURL struct for a `Buckets.Object`.
  """
  @callback url(object :: Buckets.Object.t()) :: Buckets.Object.t()

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
  Same as `c:url/1` but returns the SignedURL raises if there is an error.
  """
  @callback url!(object :: Buckets.Object.t(), opts :: Keyword.t()) :: Buckets.Object.t()

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
    otp_app =
      opts[:otp_app] ||
        raise """
        Must specify a :otp_app option when using Buckets.Cloud.
        """

    quote do
      @behaviour Buckets.Cloud

      def start_link(opts \\ []) do
        Buckets.Cloud.Supervisor.start_link(Keyword.put(opts, :cloud_module, __MODULE__))
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

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

      def url(object, opts \\ []) do
        Buckets.Cloud.Operations.url(object, opts)
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

      def url!(object, opts \\ []) do
        Buckets.Cloud.Operations.url!(object, opts)
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

      def config() do
        Buckets.Cloud.Dynamic.config(__MODULE__, unquote(otp_app))
      end

      def put_dynamic_config(config) when is_list(config) do
        Buckets.Cloud.Dynamic.put_dynamic_config(__MODULE__, config)
      end

      def with_config(config, fun) when is_list(config) and is_function(fun, 0) do
        Buckets.Cloud.Dynamic.with_config(__MODULE__, config, fun)
      end
    end
  end
end
