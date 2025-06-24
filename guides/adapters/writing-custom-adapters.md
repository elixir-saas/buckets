# Writing Custom Adapters

This guide explains how to create your own storage adapter for Buckets.

## Overview

An adapter implements the `Buckets.Adapter` behaviour to provide storage operations for a specific backend. You might create a custom adapter for:

- Proprietary storage systems
- Specialized cloud providers
- Hybrid storage solutions
- Testing purposes

## Basic Structure

```elixir
defmodule MyApp.Adapters.CustomStorage do
  @behaviour Buckets.Adapter

  @impl true
  def validate_config(config) do
    # Validate configuration
  end

  @impl true
  def put(object, remote_path, config) do
    # Upload object
  end

  @impl true
  def get(remote_path, config) do
    # Download data
  end

  @impl true
  def delete(remote_path, config) do
    # Delete object
  end

  @impl true
  def url(remote_path, config) do
    # Generate signed URL
  end

  # Optional - only if you need supervised processes
  @impl true
  def child_spec(config, cloud_module) do
    # Return supervisor child specification
  end
end
```

## Implementing Callbacks

### validate_config/1

Validates and normalizes configuration:

```elixir
@impl true
def validate_config(config) do
  with {:ok, config} <- Keyword.validate(config, [
         :adapter,
         :bucket,
         :api_key,
         :endpoint,
         :path
       ]),
       {:ok, config} <- Buckets.Adapter.validate_required(config, [
         :bucket,
         :api_key,
         :endpoint
       ]) do
    {:ok, config}
  end
end
```

### put/3

Uploads an object to storage:

```elixir
@impl true
def put(%Buckets.Object{} = object, remote_path, config) do
  data = Buckets.Object.read!(object)
  
  case upload_to_storage(remote_path, data, config) do
    :ok -> 
      {:ok, %{}}
    
    {:error, reason} -> 
      {:error, reason}
  end
end
```

### get/2

Downloads data from storage:

```elixir
@impl true
def get(remote_path, config) do
  case download_from_storage(remote_path, config) do
    {:ok, data} -> 
      {:ok, data}
      
    {:error, :not_found} -> 
      {:error, :not_found}
      
    {:error, reason} -> 
      {:error, reason}
  end
end
```

### delete/2

Deletes an object:

```elixir
@impl true
def delete(remote_path, config) do
  case delete_from_storage(remote_path, config) do
    :ok -> 
      {:ok, %{}}
      
    {:error, reason} -> 
      {:error, reason}
  end
end
```

### url/2

Generates signed URLs:

```elixir
@impl true
def url(remote_path, config) do
  expires_in = Keyword.get(config, :expires_in, 3600)
  for_upload = Keyword.get(config, :for_upload, false)
  
  signed_url = generate_signed_url(
    remote_path, 
    expires_in, 
    for_upload,
    config
  )
  
  location = Buckets.Location.new(remote_path, config)
  
  {:ok, %Buckets.SignedURL{
    url: signed_url,
    location: location
  }}
end
```

### child_spec/2 (Optional)

For adapters needing background processes:

```elixir
@impl true
def child_spec(config, cloud_module) do
  %{
    id: {__MODULE__, cloud_module},
    start: {MyApp.AuthServer, :start_link, [[
      cloud: cloud_module,
      config: config
    ]]},
    restart: :permanent
  }
end
```

## Best Practices

### 1. Configuration Validation

Always validate configuration thoroughly:

```elixir
def validate_config(config) do
  # Use Keyword.validate for known options
  with {:ok, config} <- Keyword.validate(config, @known_opts),
       # Check required fields
       {:ok, config} <- validate_required(config, @required_opts),
       # Custom validation
       :ok <- validate_endpoint(config[:endpoint]) do
    {:ok, config}
  end
end
```

### 2. Error Handling

Return consistent error tuples:

```elixir
# Good
{:error, :not_found}
{:error, :unauthorized}
{:error, {:http_error, 500}}

# Bad
{:error, "not found"}
:error
nil
```

### 3. Metadata Handling

Use object metadata appropriately:

```elixir
def put(object, path, config) do
  headers = build_headers(object.metadata)
  # Include content-type, cache-control, etc.
end
```

### 4. Telemetry Integration

Emit telemetry events:

```elixir
def put(object, path, config) do
  metadata = %{
    adapter: __MODULE__,
    path: path,
    size: byte_size(data)
  }
  
  :telemetry.span(
    [:my_adapter, :put],
    metadata,
    fn ->
      result = do_upload(object, path, config)
      {result, metadata}
    end
  )
end
```

## Testing Your Adapter

Create comprehensive tests:

```elixir
defmodule MyApp.Adapters.CustomStorageTest do
  use ExUnit.Case
  
  setup do
    config = [
      adapter: MyApp.Adapters.CustomStorage,
      bucket: "test-bucket",
      api_key: "test-key"
    ]
    
    {:ok, config: config}
  end
  
  test "validates configuration", %{config: config} do
    assert {:ok, _} = MyApp.Adapters.CustomStorage.validate_config(config)
    
    invalid = Keyword.delete(config, :bucket)
    assert {:error, [:bucket]} = MyApp.Adapters.CustomStorage.validate_config(invalid)
  end
  
  test "uploads objects", %{config: config} do
    object = Buckets.Object.from_file("test/fixtures/sample.pdf")
    
    assert {:ok, _} = MyApp.Adapters.CustomStorage.put(
      object,
      "test/sample.pdf",
      config
    )
  end
end
```

## Example: FTP Adapter

Here's a simplified FTP adapter example:

```elixir
defmodule MyApp.Adapters.FTP do
  @behaviour Buckets.Adapter
  
  @impl true
  def validate_config(config) do
    with {:ok, config} <- Keyword.validate(config, [
           :adapter, :host, :port, :username, 
           :password, :bucket, :path
         ]),
         {:ok, config} <- validate_required(config, [
           :host, :username, :password, :bucket
         ]) do
      config = Keyword.put_new(config, :port, 21)
      {:ok, config}
    end
  end
  
  @impl true
  def put(object, remote_path, config) do
    with {:ok, conn} <- connect(config),
         {:ok, data} <- Buckets.Object.read(object),
         :ok <- ftp_put(conn, remote_path, data) do
      {:ok, %{}}
    end
  end
  
  @impl true
  def get(remote_path, config) do
    with {:ok, conn} <- connect(config),
         {:ok, data} <- ftp_get(conn, remote_path) do
      {:ok, data}
    end
  end
  
  # ... implement other callbacks
end
```

## Publishing Your Adapter

1. Create a separate package
2. Name it `buckets_[provider]` (e.g., `buckets_ftp`)
3. Add buckets as a dependency
4. Document configuration options
5. Provide usage examples
6. Publish to Hex.pm

## Need Help?

- Check existing adapters for examples
- Review the `Buckets.Adapter` behaviour documentation
- Open an issue for clarification
- Submit a PR to improve this guide!