defmodule Buckets.Strategy.GCS.AuthServer do
  @moduledoc """
  GenServer that manages Google Cloud Storage access tokens.

  Automatically refreshes tokens before they expire to ensure
  uninterrupted access to GCS APIs.
  """

  use GenServer
  require Logger

  alias Buckets.Strategy.GCS.Auth

  # Refresh 5 minutes before expiry
  @refresh_margin_seconds 300

  @doc """
  Starts the token server for the given cloud module and location key.
  """
  def start_link(cloud_module, location_key, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, {cloud_module, location_key}, name: name)
  end

  @doc """
  Gets a valid access token, refreshing if necessary.
  """
  def get_token(server \\ __MODULE__) do
    GenServer.call(server, :get_token)
  end

  @doc """
  Forces a token refresh.
  """
  def refresh_token(server \\ __MODULE__) do
    GenServer.call(server, :refresh_token)
  end

  ## Impl

  @impl true
  def init({cloud_module, location_key}) do
    case load_credentials_for_location(cloud_module, location_key) do
      {:ok, credentials} ->
        # Start with no token - will be fetched on first request
        state = %{
          credentials: credentials,
          location_key: location_key,
          token: nil,
          expires_at: nil,
          refresh_timer: nil
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, {:credential_load_failed, location_key, reason}}
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
    case fetch_new_token(state) do
      {:ok, _token, new_state} ->
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to refresh GCS token: #{inspect(reason)}")
        # Schedule retry in 30 seconds
        timer = Process.send_after(self(), :refresh_token, 30_000)
        {:noreply, %{state | refresh_timer: timer}}
    end
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
  end

  defp token_expired?(state) do
    case state.expires_at do
      nil -> true
      expires_at -> System.system_time(:second) >= expires_at - @refresh_margin_seconds
    end
  end

  defp load_credentials_for_location(cloud_module, location_key) do
    Auth.get_credentials(cloud_module.config_for(location_key))
  end
end
