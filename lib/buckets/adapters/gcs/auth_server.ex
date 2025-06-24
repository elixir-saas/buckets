defmodule Buckets.Adapters.GCS.AuthServer do
  @moduledoc """
  GenServer that manages Google Cloud Storage access tokens.

  Automatically refreshes tokens before they expire to ensure uninterrupted access to GCS APIs.
  """

  use GenServer
  require Logger

  alias Buckets.Adapters.GCS.Auth
  alias Buckets.Telemetry

  # Refresh 5 minutes before expiry
  @refresh_margin_seconds 300

  @doc """
  Starts the token server.

  If opts[:cloud] exists, starts in named mode with the cloud module.
  Otherwise, treats opts as config and starts in nameless mode.
  """
  def start_link(opts) do
    case opts[:cloud] do
      cloud_module when is_atom(cloud_module) ->
        # Named mode: derive config from cloud module
        config = cloud_module.config()
        name = Module.concat(cloud_module, GCS.AuthServer)
        GenServer.start_link(__MODULE__, {cloud_module, config}, name: name)

      nil ->
        # Nameless mode: treat opts as config
        GenServer.start_link(__MODULE__, {nil, opts})
    end
  end

  @doc """
  Gets a valid access token from a specific server, refreshing if necessary.
  """
  def get_token(server) do
    GenServer.call(server, :get_token)
  end

  @doc """
  Forces a token refresh.
  """
  def refresh_token(server) do
    GenServer.call(server, :refresh_token)
  end

  ## Impl

  @impl true
  def init({cloud_module, config}) do
    case Auth.get_credentials(config) do
      {:ok, credentials} ->
        # Start with no token - will be fetched on first request
        state = %{
          credentials: credentials,
          cloud_module: cloud_module,
          config: config,
          token: nil,
          expires_at: nil,
          refresh_timer: nil
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, {:credential_load_failed, cloud_module || :dynamic, reason}}
    end
  end

  @impl true
  def handle_call(:get_token, _from, state) do
    case ensure_valid_token(state) do
      {:ok, token, new_state} ->
        {:reply, {:ok, token}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:refresh_token, _from, state) do
    case fetch_new_token(state) do
      {:ok, _token, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:refresh_token, state) do
    metadata = %{
      cloud_module: state.cloud_module,
      client_email: state.credentials["client_email"]
    }

    stop_telemetry = Telemetry.start_event([:buckets, :auth, :token, :refresh], metadata)

    result =
      case fetch_new_token(state) do
        {:ok, _token, new_state} ->
          {:noreply, new_state}

        {:error, reason} ->
          Logger.error("Failed to refresh GCS token: #{inspect(reason)}")
          # Schedule retry in 30 seconds
          timer = Process.send_after(self(), :refresh_token, 30_000)
          {:noreply, %{state | refresh_timer: timer}}
      end

    stop_telemetry.(%{})
    result
  end

  ## Private

  defp ensure_valid_token(state) do
    cond do
      state.token == nil ->
        # No token yet, fetch one
        fetch_new_token(state)

      token_expired?(state) ->
        # Token expired, refresh it
        fetch_new_token(state)

      true ->
        # Token is still valid
        {:ok, state.token, state}
    end
  end

  defp fetch_new_token(state) do
    metadata = %{
      cloud_module: state.cloud_module,
      client_email: state.credentials["client_email"]
    }

    Telemetry.span([:buckets, :auth, :token, :fetch], metadata, fn ->
      case Auth.get_access_token(state.credentials) do
        {:ok, token} ->
          # Tokens typically expire in 3600 seconds (1 hour)
          expires_at = System.system_time(:second) + 3600

          # Cancel existing timer
          if state.refresh_timer do
            Process.cancel_timer(state.refresh_timer)
          end

          # Schedule refresh before expiry
          refresh_in = 3600 - @refresh_margin_seconds
          timer = Process.send_after(self(), :refresh_token, refresh_in * 1000)

          new_state = %{
            state
            | token: token,
              expires_at: expires_at,
              refresh_timer: timer
          }

          Logger.debug("GCS token refreshed, expires at #{expires_at}")
          {:ok, token, new_state}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  defp token_expired?(state) do
    case state.expires_at do
      nil -> true
      expires_at -> System.system_time(:second) >= expires_at - @refresh_margin_seconds
    end
  end
end
