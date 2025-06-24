defmodule Buckets.Location do
  @moduledoc """
  Represents a storage location for a Buckets.Object.

  The config field can be either:
  - A keyword list with adapter configuration
  - A Cloud module atom that implements the Buckets.Cloud behaviour
  """

  @derive {Inspect, except: [:config]}

  @type t :: %__MODULE__{
          path: String.t(),
          config: Keyword.t() | module()
        }

  defstruct [:path, :config]

  defmodule NotConfigured do
    @moduledoc """
    Represents an object that hasn't been assigned a storage location yet.

    This struct is used as the default location for newly created `Buckets.Object`
    instances that haven't been uploaded to any storage backend. It serves as a
    marker to indicate that the object exists only in memory or as a local file,
    but hasn't been persisted to cloud storage.

    ## Usage

    Objects with a `NotConfigured` location:
    - Cannot be read from remote storage
    - Cannot generate signed URLs
    - Must be inserted into a Cloud module before remote operations

    ## Examples

        # New objects start with NotConfigured location
        object = Buckets.Object.new("123", "document.pdf")
        # object.location == %Buckets.Location.NotConfigured{}

        # After insertion, location is configured
        {:ok, stored} = MyApp.Cloud.insert(object)
        # stored.location == %Buckets.Location{path: "...", config: ...}
    """
    defstruct []
  end

  @doc """
  Creates a new Location struct with the given path and configuration.

  ## Parameters

  - `path` - The storage path for the object (e.g., "uploads/123/file.pdf")
  - `config` - Either:
    - A keyword list with adapter configuration
    - A Cloud module atom that implements the Buckets.Cloud behaviour

  ## Examples

      # With explicit configuration
      location = Location.new("uploads/file.pdf", [
        adapter: Buckets.Adapters.S3,
        bucket: "my-bucket",
        region: "us-east-1"
      ])

      # With Cloud module reference
      location = Location.new("uploads/file.pdf", MyApp.Cloud)

  ## Returns

  A `%Buckets.Location{}` struct with the path and configuration set.
  """
  def new(path, config) do
    %__MODULE__{
      path: path,
      config: config
    }
  end

  @doc """
  Gets the configuration from a Location.

  If the config is a keyword list, returns it as-is.
  If the config is a Cloud module, calls the module's config/0 function.
  """
  @spec get_config(t()) :: Keyword.t()
  def get_config(%__MODULE__{config: config}) when is_list(config), do: config

  def get_config(%__MODULE__{config: cloud_module}) when is_atom(cloud_module) do
    if function_exported?(cloud_module, :config, 0) do
      cloud_module.config()
    else
      raise ArgumentError,
            "Expected #{inspect(cloud_module)} to be a Cloud module with a config/0 function"
    end
  end
end
