# Telemetry and Monitoring

This guide covers monitoring and observability for Buckets operations using Telemetry.

## Overview

Buckets emits telemetry events for all major operations, allowing you to monitor performance, track errors, and gather metrics about your file storage operations.

## Available Events

### Cloud Operations

- `[:buckets, :cloud, :insert, :start]` - File upload started
- `[:buckets, :cloud, :insert, :stop]` - File upload completed
- `[:buckets, :cloud, :insert, :exception]` - File upload failed
- `[:buckets, :cloud, :read, :start]` - File read started
- `[:buckets, :cloud, :read, :stop]` - File read completed
- `[:buckets, :cloud, :delete, :start]` - File deletion started
- `[:buckets, :cloud, :delete, :stop]` - File deletion completed
- `[:buckets, :cloud, :url, :start]` - URL generation started
- `[:buckets, :cloud, :url, :stop]` - URL generation completed

### Adapter Operations

- `[:buckets, :adapter, :put, :start]` - Adapter upload started
- `[:buckets, :adapter, :put, :stop]` - Adapter upload completed
- `[:buckets, :adapter, :get, :start]` - Adapter download started
- `[:buckets, :adapter, :get, :stop]` - Adapter download completed

## Basic Setup

```elixir
defmodule MyApp.Telemetry do
  require Logger

  def setup do
    events = [
      [:buckets, :cloud, :insert, :start],
      [:buckets, :cloud, :insert, :stop],
      [:buckets, :cloud, :insert, :exception],
      [:buckets, :cloud, :read, :stop],
      [:buckets, :cloud, :delete, :stop],
      [:buckets, :cloud, :url, :stop]
    ]

    :telemetry.attach_many(
      "buckets-handler",
      events,
      &handle_event/4,
      nil
    )
  end

  defp handle_event([:buckets, :cloud, :insert, :stop], measurements, metadata, _config) do
    Logger.info("File uploaded",
      duration_ms: measurements.duration / 1_000_000,
      filename: metadata.filename,
      cloud: metadata.cloud_module
    )
  end

  defp handle_event([:buckets, :cloud, :insert, :exception], _measurements, metadata, _config) do
    Logger.error("File upload failed",
      error: inspect(metadata.error),
      filename: metadata.filename
    )
  end

  # Handle other events...
end
```

## Metrics Collection

For detailed metrics and monitoring, integrate with your preferred metrics system.

### StatsD Integration

```elixir
defmodule MyApp.Metrics.StatsD do
  def setup do
    :telemetry.attach_many(
      "buckets-statsd",
      buckets_events(),
      &handle_event/4,
      nil
    )
  end

  defp handle_event([:buckets, :cloud, event, :stop], measurements, metadata, _config) do
    # Record timing
    StatsD.histogram(
      "buckets.cloud.#{event}.duration",
      measurements.duration / 1_000_000,
      tags: ["adapter:#{metadata.adapter}", "cloud:#{cloud_name(metadata)}"]
    )

    # Count operations
    StatsD.increment(
      "buckets.cloud.#{event}.count",
      tags: ["adapter:#{metadata.adapter}"]
    )
  end

  defp handle_event([:buckets, :cloud, event, :exception], _measurements, metadata, _config) do
    StatsD.increment(
      "buckets.cloud.#{event}.error",
      tags: ["adapter:#{metadata.adapter}", "error:#{error_type(metadata.error)}"]
    )
  end
end
```

### Prometheus Integration

```elixir
defmodule MyApp.Metrics.Prometheus do
  use Prometheus.Metric

  def setup do
    # Define metrics
    Histogram.new(
      name: :buckets_operation_duration_seconds,
      help: "Duration of bucket operations",
      labels: [:operation, :adapter, :cloud],
      buckets: [0.01, 0.05, 0.1, 0.5, 1, 5, 10]
    )

    Counter.new(
      name: :buckets_operations_total,
      help: "Total number of bucket operations",
      labels: [:operation, :adapter, :cloud, :status]
    )

    # Attach handlers
    :telemetry.attach_many(
      "buckets-prometheus",
      buckets_events(),
      &handle_event/4,
      nil
    )
  end

  defp handle_event([:buckets, :cloud, operation, :stop], measurements, metadata, _config) do
    Histogram.observe(
      [name: :buckets_operation_duration_seconds],
      measurements.duration / 1_000_000_000,
      labels: [operation, metadata.adapter, cloud_name(metadata)]
    )

    Counter.inc(
      [name: :buckets_operations_total],
      labels: [operation, metadata.adapter, cloud_name(metadata), "success"]
    )
  end
end
```

## Custom Metrics

Add your own metrics around Buckets operations:

```elixir
defmodule MyApp.Storage.Metrics do
  def upload_with_metrics(file_path) do
    start_time = System.monotonic_time()
    file_size = File.stat!(file_path).size

    metadata = %{
      file_path: file_path,
      file_size: file_size
    }

    :telemetry.span(
      [:my_app, :storage, :upload],
      metadata,
      fn ->
        object = Buckets.Object.from_file(file_path)
        result = MyApp.Cloud.insert(object)
        
        {result, Map.put(metadata, :stored?, match?({:ok, _}, result))}
      end
    )
  end
end
```

## Performance Monitoring

Track performance across different adapters and operations:

```elixir
defmodule MyApp.PerformanceMonitor do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_state) do
    :telemetry.attach_many(
      "performance-monitor",
      [
        [:buckets, :adapter, :put, :stop],
        [:buckets, :adapter, :get, :stop]
      ],
      &handle_event/4,
      nil
    )

    {:ok, %{}}
  end

  defp handle_event([_, _, operation, :stop], measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:record, operation, measurements, metadata})
  end

  def handle_cast({:record, operation, measurements, metadata}, state) do
    key = {metadata.adapter, operation}
    duration_ms = measurements.duration / 1_000_000

    # Alert if slow
    if duration_ms > 5000 do
      Logger.warn("Slow #{operation} operation",
        adapter: metadata.adapter,
        duration_ms: duration_ms,
        path: metadata.path
      )
    end

    # Update rolling average
    new_state = Map.update(state, key, [duration_ms], fn durations ->
      [duration_ms | Enum.take(durations, 99)]
    end)

    {:noreply, new_state}
  end
end
```

## Error Tracking

Monitor and alert on errors:

```elixir
defmodule MyApp.ErrorTracker do
  def setup do
    :telemetry.attach(
      "error-tracker",
      [:buckets, :cloud, :insert, :exception],
      &track_error/4,
      nil
    )
  end

  defp track_error(_event, _measurements, metadata, _config) do
    Sentry.capture_exception(metadata.error,
      stacktrace: metadata.stacktrace,
      extra: %{
        filename: metadata.filename,
        cloud_module: metadata.cloud_module,
        adapter: metadata.adapter
      }
    )
  end
end
```

## Dashboards

Create dashboards to visualize your storage metrics:

### Grafana Dashboard

Key panels to include:
- Upload/download rate
- Operation duration percentiles
- Error rate by adapter
- Storage usage trends
- Concurrent operations

### Example Query (Prometheus)

```promql
# Upload success rate
rate(buckets_operations_total{operation="insert",status="success"}[5m])
/
rate(buckets_operations_total{operation="insert"}[5m])

# P95 upload duration
histogram_quantile(0.95,
  rate(buckets_operation_duration_seconds_bucket{operation="insert"}[5m])
)
```

## Best Practices

1. **Sample high-volume events** - Avoid overwhelming metrics systems
2. **Use consistent labels** - Maintain standard label naming
3. **Alert on anomalies** - Set up alerts for error spikes
4. **Track business metrics** - Not just technical metrics
5. **Monitor costs** - Track usage that affects billing
6. **Regular review** - Analyze metrics for optimization opportunities

## Next Steps

- Implement [Security Monitoring](security-best-practices.html)
- Set up [Performance Optimization](performance-optimization.html)
- Configure [Production Monitoring](../deployment/production-checklist.html)