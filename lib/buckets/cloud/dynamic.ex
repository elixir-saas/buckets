defmodule Buckets.Cloud.Dynamic do
  @moduledoc """
  Dynamic configuration management for Cloud modules.

  This module provides functions for managing runtime configuration changes,
  allowing Cloud modules to switch between different adapters and configurations
  on a per-process basis, similar to `Ecto.Repo.put_dynamic_repo/1`.

  ## Usage

  These functions are automatically available on Cloud modules that use
  `Buckets.Cloud`. You typically don't need to call this module directly.

  ### Process-Local Configuration

      MyApp.Cloud.put_dynamic_config([
        adapter: Buckets.Adapters.GCS,
        bucket: "tenant-bucket",
        service_account_credentials: credentials
      ])

  ### Scoped Configuration

      MyApp.Cloud.with_config(config, fn ->
        MyApp.Cloud.insert("file.pdf")
      end)

  ## Auth Server Management

  For adapters that need background processes (like GCS auth servers), these
  are automatically started and cached per-process as needed through the
  adapter's `prepare_dynamic_config/1` callback.
  """

  require Logger

  @doc """
  Gets the current configuration for the given cloud module.

  Checks the process dictionary first for dynamic config, falls back to static config.
  """
  def config(cloud_module, otp_app) do
    # Check process dictionary first for dynamic config (like Ecto.Repo)
    case Process.get({cloud_module, :dynamic_config}) do
      nil ->
        # Use static config from application environment
        static_config(cloud_module, otp_app)

      dynamic_config ->
        # Dynamic config is already validated and enhanced when stored
        dynamic_config
    end
  end

  @doc """
  Sets dynamic configuration for the current process.

  This configuration will be used for all subsequent operations in this process
  until changed or deleted.
  """
  def put_dynamic_config(cloud_module, config) when is_list(config) do
    validated_config = validate_and_enhance_config(config)
    Process.put({cloud_module, :dynamic_config}, validated_config)
    :ok
  end

  @doc """
  Executes a function with a specific configuration.

  The configuration is only active during the execution of the function.
  Previous configuration is restored afterwards.
  """
  def with_config(cloud_module, config, fun) when is_list(config) and is_function(fun, 0) do
    # Store previous config (if any)
    previous_config = Process.get({cloud_module, :dynamic_config})

    # Set the dynamic config
    put_dynamic_config(cloud_module, config)

    try do
      # Execute the function
      fun.()
    after
      # Always restore previous config
      case previous_config do
        nil -> Process.delete({cloud_module, :dynamic_config})
        config -> Process.put({cloud_module, :dynamic_config}, config)
      end
    end
  end

  ## Private

  defp static_config(cloud_module, otp_app) do
    config =
      case Application.fetch_env(otp_app, cloud_module) do
        {:ok, config} ->
          config

        :error ->
          # Default to Volume adapter with sensible defaults
          Logger.warning("""
          No configuration found for #{inspect(cloud_module)} in application #{inspect(otp_app)}.
          Using default Volume adapter configuration.

          To configure your cloud module, add the following to your config:

              config #{inspect(otp_app)}, #{inspect(cloud_module)},
                adapter: Buckets.Adapters.Volume,
                bucket: "tmp/buckets_volume",
                base_url: "http://localhost:4000"
          """)

          [
            adapter: Buckets.Adapters.Volume,
            bucket: "tmp/buckets_volume",
            base_url: "http://localhost:4000"
          ]
      end

    adapter =
      config[:adapter] ||
        raise "Cloud config must always include an :adapter value."

    case adapter.validate_config(config) do
      {:ok, validated_config} ->
        validated_config

      {:error, invalid_keys} ->
        raise "Invalid or missing keys in cloud config: #{inspect(invalid_keys)}"
    end
  end

  defp validate_and_enhance_config(config) do
    adapter =
      config[:adapter] ||
        raise "Config must always include an :adapter value."

    case adapter.validate_config(config) do
      {:ok, validated_config} ->
        # Let adapter handle auth server setup if needed
        ensure_adapter_requirements(validated_config)

      {:error, invalid_keys} ->
        raise "Invalid or missing keys in config: #{inspect(invalid_keys)}"
    end
  end

  defp ensure_adapter_requirements(config) do
    adapter = config[:adapter]

    # If adapter implements child_spec/2, it needs supervised processes for dynamic config
    if function_exported?(adapter, :child_spec, 2) do
      start_adapter_processes(config, adapter)
    else
      # Adapter doesn't need supervised processes
      config
    end
  end

  defp start_adapter_processes(config, adapter) do
    # Use a simple cache key per adapter type
    cache_key = {adapter, :dynamic_process}

    case Process.get(cache_key) do
      pid when is_pid(pid) ->
        # Check if process is still alive
        if Process.alive?(pid) do
          # Reuse existing process
          Keyword.put(config, :__auth_server_pid__, pid)
        else
          # Start new process
          start_and_cache_process(config, adapter, cache_key)
        end

      nil ->
        # Start new process
        start_and_cache_process(config, adapter, cache_key)
    end
  end

  defp start_and_cache_process(config, adapter, cache_key) do
    case adapter.child_spec(config, nil) do
      %{start: {module, :start_link, [args]}} ->
        case module.start_link(args) do
          {:ok, pid} ->
            # Cache the process pid in this process
            Process.put(cache_key, pid)
            Keyword.put(config, :__auth_server_pid__, pid)

          {:error, reason} ->
            raise "Failed to start adapter process: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise "Invalid adapter child spec: #{inspect(reason)}"
    end
  end
end
