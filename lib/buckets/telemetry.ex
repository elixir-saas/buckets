defmodule Buckets.Telemetry do
  @moduledoc """
  Telemetry events for Buckets.

  This module defines telemetry events that other applications can attach to.

  ## Event Format

  Events follow the convention: `[:buckets, component, operation, stage]`

  ## Events

  ### Cloud Operations

  * `[:buckets, :cloud, :insert, :start]` - Emitted when a file upload operation starts
  * `[:buckets, :cloud, :insert, :stop]` - Emitted when a file upload operation completes
  * `[:buckets, :cloud, :insert, :exception]` - Emitted when a file upload operation raises an exception
  * `[:buckets, :cloud, :delete, :start]` - Emitted when a file deletion operation starts
  * `[:buckets, :cloud, :delete, :stop]` - Emitted when a file deletion operation completes
  * `[:buckets, :cloud, :delete, :exception]` - Emitted when a file deletion operation raises an exception
  * `[:buckets, :cloud, :read, :start]` - Emitted when a file read operation starts
  * `[:buckets, :cloud, :read, :stop]` - Emitted when a file read operation completes
  * `[:buckets, :cloud, :read, :exception]` - Emitted when a file read operation raises an exception
  * `[:buckets, :cloud, :load, :start]` - Emitted when a file load operation starts
  * `[:buckets, :cloud, :load, :stop]` - Emitted when a file load operation completes
  * `[:buckets, :cloud, :load, :exception]` - Emitted when a file load operation raises an exception
  * `[:buckets, :cloud, :copy, :start]` - Emitted when a file copy operation starts
  * `[:buckets, :cloud, :copy, :stop]` - Emitted when a file copy operation completes
  * `[:buckets, :cloud, :copy, :exception]` - Emitted when a file copy operation raises an exception
  * `[:buckets, :cloud, :url, :start]` - Emitted when a URL generation operation starts
  * `[:buckets, :cloud, :url, :stop]` - Emitted when a URL generation operation completes
  * `[:buckets, :cloud, :url, :exception]` - Emitted when a URL generation operation raises an exception

  ### Adapter Operations

  * `[:buckets, :adapter, :put, :start]` - Emitted when an adapter put operation starts
  * `[:buckets, :adapter, :put, :stop]` - Emitted when an adapter put operation completes
  * `[:buckets, :adapter, :put, :exception]` - Emitted when an adapter put operation raises an exception
  * `[:buckets, :adapter, :get, :start]` - Emitted when an adapter get operation starts
  * `[:buckets, :adapter, :get, :stop]` - Emitted when an adapter get operation completes
  * `[:buckets, :adapter, :get, :exception]` - Emitted when an adapter get operation raises an exception
  * `[:buckets, :adapter, :url, :start]` - Emitted when an adapter URL generation starts
  * `[:buckets, :adapter, :url, :stop]` - Emitted when an adapter URL generation completes
  * `[:buckets, :adapter, :url, :exception]` - Emitted when an adapter URL generation raises an exception
  * `[:buckets, :adapter, :copy, :start]` - Emitted when an adapter copy operation starts
  * `[:buckets, :adapter, :copy, :stop]` - Emitted when an adapter copy operation completes
  * `[:buckets, :adapter, :copy, :exception]` - Emitted when an adapter copy operation raises an exception
  * `[:buckets, :adapter, :delete, :start]` - Emitted when an adapter delete operation starts
  * `[:buckets, :adapter, :delete, :stop]` - Emitted when an adapter delete operation completes
  * `[:buckets, :adapter, :delete, :exception]` - Emitted when an adapter delete operation raises an exception

  ### Authentication Operations

  * `[:buckets, :auth, :token, :fetch, :start]` - Emitted when token fetching starts
  * `[:buckets, :auth, :token, :fetch, :stop]` - Emitted when token fetching completes
  * `[:buckets, :auth, :token, :fetch, :exception]` - Emitted when token fetching raises an exception
  * `[:buckets, :auth, :token, :refresh, :start]` - Emitted when token refresh starts
  * `[:buckets, :auth, :token, :refresh, :stop]` - Emitted when token refresh completes
  * `[:buckets, :auth, :token, :refresh, :exception]` - Emitted when token refresh raises an exception

  ## Usage

  To attach to these events in your application:

  ```elixir
  :telemetry.attach(
    "my-handler-id",
    [:buckets, :cloud, :insert, :start],
    &MyApp.handle_cloud_insert/4,
    nil
  )

  def handle_cloud_insert(_event_name, measurements, metadata, _config) do
    # Process the event
    IO.inspect(measurements)
    IO.inspect(metadata)
  end
  ```

  You may attach a default logger handler, if you want basic logs for all telemetry events:

  ```elixir
  Buckets.Telemetry.attach_default_logger(:debug)
  ```
  """

  require Logger

  @doc """
  Attaches a default structured JSON Telemetry handler for logging.
  """
  @spec attach_default_logger(Logger.level() | keyword()) :: :ok | {:error, :already_exists}
  def attach_default_logger(opts \\ [])

  def attach_default_logger(level) when is_atom(level) do
    attach_default_logger(level: level)
  end

  def attach_default_logger(opts) when is_list(opts) do
    opts =
      opts
      |> Keyword.put_new(:events, :all)
      |> Keyword.put_new(:level, :info)

    filter = opts[:events]

    events =
      for [category | rest] <- [
            ~w(cloud insert start)a,
            ~w(cloud insert stop)a,
            ~w(cloud insert exception)a,
            ~w(cloud delete start)a,
            ~w(cloud delete stop)a,
            ~w(cloud delete exception)a,
            ~w(cloud read start)a,
            ~w(cloud read stop)a,
            ~w(cloud read exception)a,
            ~w(cloud load start)a,
            ~w(cloud load stop)a,
            ~w(cloud load exception)a,
            ~w(cloud copy start)a,
            ~w(cloud copy stop)a,
            ~w(cloud copy exception)a,
            ~w(cloud url start)a,
            ~w(cloud url stop)a,
            ~w(cloud url exception)a,
            ~w(adapter put start)a,
            ~w(adapter put stop)a,
            ~w(adapter put exception)a,
            ~w(adapter get start)a,
            ~w(adapter get stop)a,
            ~w(adapter get exception)a,
            ~w(adapter url start)a,
            ~w(adapter url stop)a,
            ~w(adapter url exception)a,
            ~w(adapter copy start)a,
            ~w(adapter copy stop)a,
            ~w(adapter copy exception)a,
            ~w(adapter delete start)a,
            ~w(adapter delete stop)a,
            ~w(adapter delete exception)a,
            ~w(auth token fetch start)a,
            ~w(auth token fetch stop)a,
            ~w(auth token fetch exception)a,
            ~w(auth token refresh start)a,
            ~w(auth token refresh stop)a,
            ~w(auth token refresh exception)a
          ],
          filter == :all or category in filter,
          do: [:buckets, category | rest]

    :telemetry.attach_many(default_handler_id(), events, &__MODULE__.handle_event/4, opts)
  end

  @doc """
  Undoes `Buckets.Telemetry.attach_default_logger/1` by detaching the attached logger.

  ## Examples

  Detach a previously attached logger:

      :ok = Buckets.Telemetry.attach_default_logger()
      :ok = Buckets.Telemetry.detach_default_logger()

  Attempt to detach when a logger wasn't attached:

      {:error, :not_found} = Buckets.Telemetry.detach_default_logger()
  """
  @spec detach_default_logger() :: :ok | {:error, :not_found}
  def detach_default_logger do
    :telemetry.detach(default_handler_id())
  end

  def default_handler_id, do: "buckets-default-logger"

  @doc """
  Default telemetry event handler that logs events.
  """
  def handle_event(event_name, measurements, metadata, opts) do
    level = Keyword.get(opts, :level, :info)

    Logger.log(level, """
    [Buckets] #{Enum.join(event_name, ".")}
    Measurements: #{inspect(measurements)}
    Metadata: #{inspect(metadata)}
    """)
  end

  @doc """
  Emits a telemetry event with the given name, measurements, and metadata.
  """
  @spec emit_event(list(atom()), map(), map()) :: :ok
  def emit_event(event_name, measurements, metadata) do
    :telemetry.execute(event_name, measurements, metadata)
  end

  @doc """
  Emits a start event and returns a function to emit the corresponding stop event.

  This is useful for span-like events where you want to measure the duration of an operation.
  """
  @spec start_event(list(atom()), map()) :: (map() -> :ok)
  def start_event(event_prefix, metadata) do
    start_time = System.monotonic_time()
    start_system_time = System.system_time()

    emit_event(event_prefix ++ [:start], %{system_time: start_system_time}, metadata)

    fn additional_metadata ->
      end_time = System.monotonic_time()
      duration = end_time - start_time

      emit_event(
        event_prefix ++ [:stop],
        %{duration: duration, system_time: System.system_time()},
        Map.merge(metadata, additional_metadata)
      )
    end
  end

  @doc """
  Wraps a function call with start and stop telemetry events.
  """
  @spec span(list(atom()), map(), (-> result)) :: result when result: any()
  def span(event_prefix, metadata, fun) do
    stop = start_event(event_prefix, metadata)

    try do
      result = fun.()
      stop.(%{result: result})
      result
    rescue
      exception ->
        stacktrace = __STACKTRACE__

        emit_event(
          event_prefix ++ [:exception],
          %{system_time: System.system_time()},
          Map.merge(metadata, %{
            kind: :error,
            error: exception,
            stacktrace: stacktrace
          })
        )

        reraise exception, stacktrace
    end
  end
end
