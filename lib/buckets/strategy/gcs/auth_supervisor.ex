defmodule Buckets.Strategy.GCS.AuthSupervisor do
  @moduledoc """
  Supervisor that manages AuthServer processes for GCS locations in a Cloud module.

  Simply starts one AuthServer per GCS location found in the Cloud configuration.
  The AuthServers handle their own credential loading and validation.
  """

  use Supervisor
  require Logger

  alias Buckets.Strategy.GCS.AuthServer

  @doc """
  Starts the supervisor with a Cloud module.

  ## Options

      * `:cloud` - The module that uses `Buckets.Cloud` (required)

  """
  def start_link(opts) do
    cloud =
      opts[:cloud] ||
        raise """
        Must configure a :cloud module when starting Buckets.Strategy.GCS.AuthSupervisor.
        """

    Supervisor.start_link(__MODULE__, cloud, name: __MODULE__)
  end

  ## Impl

  @impl true
  def init(cloud_module) do
    children =
      for location_key <- get_gcs_location_keys(cloud_module) do
        server_name = server_name_for_location(location_key)

        %{
          id: {AuthServer, location_key},
          start: {AuthServer, :start_link, [cloud_module, location_key, [name: server_name]]},
          restart: :permanent
        }
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Gets an access token for the given config (which should include __location_key__).
  """
  def get_token(config) when is_list(config) do
    case Keyword.get(config, :__location_key__) do
      nil ->
        {:error, {:location_key_missing, "Config must include :__location_key__ for auth lookup"}}

      location_key ->
        server_name = server_name_for_location(location_key)

        case GenServer.whereis(server_name) do
          nil ->
            {:error, {:auth_server_not_found, "No AuthServer found for location #{location_key}"}}

          _pid ->
            AuthServer.get_token(server_name)
        end
    end
  end

  ## Private

  defp get_gcs_location_keys(cloud_module) do
    cloud_module.locations()
    |> Enum.filter(fn {_key, config} -> config[:strategy] == Buckets.Strategy.GCS end)
    |> Enum.map(fn {key, _config} -> key end)
  end

  defp server_name_for_location(location_key) do
    Module.concat(Buckets.Strategy.GCS.AuthServer, Macro.camelize(to_string(location_key)))
  end
end
