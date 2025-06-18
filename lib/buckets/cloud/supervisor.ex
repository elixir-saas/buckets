defmodule Buckets.Cloud.Supervisor do
  @moduledoc """
  Supervisor that manages any processes required by cloud adapters.

  This supervisor is used internally by Cloud modules to automatically
  start any required processes for configured adapters by calling the
  adapter's `child_spec/1` callback. Adapters that don't need supervised
  processes (like Volume, S3) return `nil`, while adapters that need
  background processes (like GCS auth servers) return proper child specs.
  """

  use Supervisor
  require Logger

  @doc """
  Starts the supervisor with a Cloud module.
  """
  def start_link(opts) do
    cloud_module = Keyword.fetch!(opts, :cloud_module)
    opts = [name: Module.concat(cloud_module, Supervisor)]

    Supervisor.start_link(__MODULE__, cloud_module, opts)
  end

  ## Impl

  @impl true
  def init(cloud_module) do
    config = cloud_module.config()
    adapter = config[:adapter]

    children =
      if function_exported?(adapter, :child_spec, 2) do
        case adapter.child_spec(config, cloud_module) do
          child_spec when is_map(child_spec) ->
            [child_spec]

          {:error, reason} ->
            raise "Adapter config invalid for #{inspect(cloud_module)}: #{reason}"
        end
      else
        []
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
