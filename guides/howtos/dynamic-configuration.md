# Dynamic Configuration

This guide explains how to configure cloud storage dynamically at runtime, enabling multi-tenant applications and flexible storage strategies.

## Overview

Dynamic configuration allows you to:
- Support multi-tenant applications with per-tenant storage
- Switch storage providers without restarting
- Test with different configurations
- Implement feature flags for storage

## Basic Dynamic Configuration

### Process-Scoped Configuration

Set configuration for the current process:

```elixir
# Set dynamic config
MyApp.Cloud.put_dynamic_config([
  adapter: Buckets.Adapters.S3,
  bucket: "tenant-123-bucket",
  region: "us-west-2",
  access_key_id: "AKIA...",
  secret_access_key: "secret..."
])

# All subsequent operations use this config
{:ok, object} = MyApp.Cloud.insert(upload)
```

### Scoped Configuration Blocks

Use configuration for a specific block of code:

```elixir
config = [
  adapter: Buckets.Adapters.GCS,
  bucket: "temporary-bucket",
  service_account_credentials: credentials
]

result = MyApp.Cloud.with_config(config, fn ->
  # All operations in this block use the config
  {:ok, obj1} = MyApp.Cloud.insert(file1)
  {:ok, obj2} = MyApp.Cloud.insert(file2)
  
  [obj1, obj2]
end)
```

## Multi-Tenant Implementation

### Basic Multi-Tenant Setup

```elixir
defmodule MyApp.TenantStorage do
  def with_tenant(tenant, fun) do
    config = build_config(tenant)
    MyApp.Cloud.with_config(config, fun)
  end
  
  defp build_config(tenant) do
    case tenant.storage_provider do
      "s3" ->
        [
          adapter: Buckets.Adapters.S3,
          bucket: tenant.s3_bucket,
          region: tenant.s3_region,
          access_key_id: decrypt(tenant.s3_access_key),
          secret_access_key: decrypt(tenant.s3_secret_key)
        ]
        
      "gcs" ->
        [
          adapter: Buckets.Adapters.GCS,
          bucket: tenant.gcs_bucket,
          service_account_credentials: decrypt(tenant.gcs_credentials)
        ]
        
      "volume" ->
        [
          adapter: Buckets.Adapters.Volume,
          bucket: "tenants/#{tenant.id}",
          base_url: tenant.base_url || "http://localhost:4000"
        ]
    end
  end
  
  defp decrypt(encrypted_value) do
    # Decrypt sensitive credentials
    MyApp.Crypto.decrypt(encrypted_value)
  end
end
```

### Phoenix Integration

Use dynamic config in Phoenix controllers:

```elixir
defmodule MyAppWeb.FileController do
  plug :load_tenant_config
  
  def upload(conn, %{"file" => upload}) do
    # Config is already set by plug
    object = Buckets.Object.from_upload(upload)
    
    case MyApp.Cloud.insert(object) do
      {:ok, stored} ->
        conn
        |> put_flash(:info, "File uploaded")
        |> redirect(to: ~p"/files")
        
      {:error, reason} ->
        conn
        |> put_flash(:error, "Upload failed: #{inspect(reason)}")
        |> redirect(to: ~p"/files/new")
    end
  end
  
  defp load_tenant_config(conn, _opts) do
    tenant = conn.assigns.current_tenant
    config = MyApp.TenantStorage.build_config(tenant)
    
    MyApp.Cloud.put_dynamic_config(config)
    conn
  end
end
```

### LiveView Integration

```elixir
defmodule MyAppWeb.UploadLive do
  use MyAppWeb, :live_view
  
  def mount(_params, session, socket) do
    tenant = get_tenant(session)
    config = MyApp.TenantStorage.build_config(tenant)
    
    # Set config for this LiveView process
    MyApp.Cloud.put_dynamic_config(config)
    
    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> allow_upload(:files, accept: :any, external: &presign_upload/2)}
  end
  
  defp presign_upload(entry, socket) do
    # Uses the dynamic config set in mount
    {:ok, config} = MyApp.Cloud.live_upload(entry)
    {:ok, config, socket}
  end
end
```

## Background Jobs

### Oban Integration

```elixir
defmodule MyApp.FileProcessor do
  use Oban.Worker
  
  @impl true
  def perform(%{args: %{"file_id" => file_id, "tenant_id" => tenant_id}}) do
    tenant = Tenants.get!(tenant_id)
    file = Files.get!(file_id)
    
    # Run with tenant's config
    MyApp.TenantStorage.with_tenant(tenant, fn ->
      # Load file data
      {:ok, object} = MyApp.Cloud.load(file.object)
      
      # Process file
      process_file(object)
      
      # Save results
      {:ok, processed} = MyApp.Cloud.insert(processed_object)
      
      Files.update(file, %{processed_path: processed.location.path})
    end)
    
    :ok
  end
end
```