defmodule Buckets.Cloud.Supervisor do
  @moduledoc """
  Supervisor that manages authentication servers for cloud adapters.

  This supervisor is used internally by Cloud modules to automatically
  start any required authentication processes for configured adapters.
  """

  use Supervisor
  require Logger

  alias Buckets.Adapters.GCS

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
    children =
      cloud_module.locations()
      |> Enum.map(fn {location_key, location} ->
        child_spec_for_location(location[:adapter], cloud_module, location_key)
      end)
      |> Enum.reject(&is_nil/1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  ## Private

  defp child_spec_for_location(Buckets.Adapters.GCS, cloud_module, location_key) do
    %{
      id: {GCS.AuthServer, location_key},
      start: {GCS.AuthServer, :start_link, [cloud_module, location_key]},
      restart: :permanent
    }
  end

  defp child_spec_for_location(_adapter, _cloud_module, _location_key), do: nil
end
