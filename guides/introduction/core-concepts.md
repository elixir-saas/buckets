# Core Concepts

Understanding these core concepts will help you use Buckets effectively.

## Cloud Modules

A Cloud module is your main interface to cloud storage, similar to how an Ecto Repo is your interface to a database. You define Cloud modules in your application:

```elixir
defmodule MyApp.Cloud do
  use Buckets.Cloud, otp_app: :my_app
end
```

Each Cloud module:
- Connects to one storage backend at a time
- Can be configured differently per environment
- Provides a consistent API regardless of the storage backend

## Adapters

Adapters implement the actual storage operations for different backends:

- **`Buckets.Adapters.Volume`** - Local filesystem (great for development)
- **`Buckets.Adapters.S3`** - Amazon S3 and compatible services
- **`Buckets.Adapters.GCS`** - Google Cloud Storage

Each adapter has its own configuration requirements and capabilities.

## Objects

`Buckets.Object` structs represent files in your system. Objects have:

- **UUID** - Unique identifier
- **Filename** - Original filename
- **Data** - The actual file content (when loaded)
- **Metadata** - Content type, size, and custom metadata
- **Location** - Where the file is stored
- **Stored?** - Whether it's been uploaded to cloud storage

### Object Lifecycle

1. **Created** - Object exists in memory/local disk
   ```elixir
   object = Buckets.Object.from_file("/tmp/upload.pdf")
   # stored?: false, location: NotConfigured
   ```

2. **Stored** - Object uploaded to cloud storage
   ```elixir
   {:ok, stored} = MyApp.Cloud.insert(object)
   # stored?: true, location: configured
   ```

3. **Loaded** - Object data fetched from cloud
   ```elixir
   {:ok, loaded} = MyApp.Cloud.load(stored)
   {:ok, data} = Buckets.Object.read(loaded)
   ```

## Locations

A `Buckets.Location` represents where an object is stored. It contains:
- **Path** - The storage path (e.g., "uploads/123/file.pdf")
- **Config** - Either adapter configuration or a Cloud module reference

## Signed URLs

Signed URLs provide temporary, secure access to objects:

```elixir
{:ok, signed_url} = MyApp.Cloud.url(object, expires_in: 3600)
# Use signed_url.url for direct access
```

These are especially useful for:
- Direct browser downloads
- LiveView direct uploads
- Temporary file sharing

## Supervision

Some adapters (like GCS) need background processes for authentication. The Cloud module supervisor handles this automatically when added to your supervision tree.

Adapters that need supervision:
- GCS (for auth token management)

Adapters that don't need supervision:
- Volume
- S3

## Configuration

Configuration can be:

### Static (compile-time)
```elixir
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.S3,
  bucket: "my-bucket"
```

### Dynamic (runtime)
```elixir
MyApp.Cloud.put_dynamic_config([
  adapter: Buckets.Adapters.S3,
  bucket: "tenant-bucket"
])
```

This enables multi-tenant applications where each tenant has their own storage configuration.