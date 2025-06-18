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
    defstruct []
  end

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
