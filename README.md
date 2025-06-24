<p align="center">
  <img src="priv/logo.png" height="150" />
</p>

---

# Buckets

A solution for storing files across multiple cloud storage providers with Phoenix integration.

Buckets provides a consistent API for uploading, downloading, and managing files whether you're using local filesystem storage for development, Google Cloud Storage, Amazon S3, or other cloud providers. It handles the complexity of different storage backends while offering advanced features like signed URLs, direct client uploads, and seamless Phoenix LiveView integration.

Supports:

- [x] File System ([`Buckets.Adapters.Volume`](./lib/buckets/adapters/volume.ex))
- [x] Google Cloud Storage ([`Buckets.Adapters.GCS`](./lib/buckets/adapters/gcs.ex))
- [x] Amazon S3 ([`Buckets.Adapters.S3`](./lib/buckets/adapters/s3.ex))
- [x] Cloudflare R2 ([`Buckets.Adapters.S3`](./lib/buckets/adapters/s3.ex) with `provider: :cloudflare`)
- [x] DigitalOcean Spaces ([`Buckets.Adapters.S3`](./lib/buckets/adapters/s3.ex) with `provider: :digitalocean`)
- [x] Tigris ([`Buckets.Adapters.S3`](./lib/buckets/adapters/s3.ex) with `provider: :tigris`)

Features:

- [x] Multi-cloud
- [x] Dynamically configured clouds
- [x] Signed URLs
- [x] Easy Plug uploads
- [x] Easy LiveView direct-to-cloud uploads
- [x] Dev router for local uploads & downloads
- [x] Telemetry

## Installation

Install by adding `buckets` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:buckets, "~> 1.0.0-rc.2"}
  ]
end
```

Full documentation at <https://hexdocs.pm/buckets>.

## Getting started

### 1. Create your Cloud module

Start by creating a single Cloud module for your application:

```elixir
defmodule MyApp.Cloud do
  use Buckets.Cloud, otp_app: :my_app
end
```

### 2. Add to your supervision tree

Some adapters (like GCS) require authentication servers, add your Cloud module to
your application supervision tree to start any required processes:

```elixir
def start(_type, _args) do
  children = [
    # ... other children
    MyApp.Cloud
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 3. Configure your Cloud module

Configure your Cloud module with different adapters for different environments:

```elixir
# Development - local filesystem
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.Volume,
  bucket: "tmp/buckets_volume",
  base_url: "http://localhost:4000",
  # Optional: base path within bucket
  path: "uploads",
  # Optional: custom endpoint for signed URLs (defaults to "/__buckets__")
  endpoint: "/__storage__",
  # Optional: uploader module for LiveView direct uploads
  uploader: "S3"

# Production - Google Cloud Storage
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.GCS,
  bucket: "my-app-production",
  # Use JSON credentials string
  service_account_credentials: System.fetch_env!("GOOGLE_CREDENTIALS"),
  # Or use path to credentials file
  # service_account_path: "/path/to/credentials.json",
  # Optional: base path within bucket
  path: "app/uploads",
  # Optional: uploader module for LiveView direct uploads
  uploader: "GCS"

# Alternative production - Amazon S3
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.S3,
  bucket: "my-app-production",
  region: "us-east-1",
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY"),
  # Optional: base path within bucket
  path: "production/files",
  # Optional: uploader module for LiveView direct uploads
  uploader: "S3"
```

## Core Concepts

### Cloud Module

The entrypoint to using Buckets is through a `Cloud`, which you declare in your application. Think of it like an Ecto Repo module, but instead of interfacing with a database, you're interfacing with remote cloud storage. Instead of mapping database rows to schema structs, it maps files to `Buckets.Object` structs.

### Adapters

**Adapters** are the actual storage implementations that handle different storage backends:
- `Buckets.Adapters.Volume` - Local filesystem storage
- `Buckets.Adapters.GCS` - Google Cloud Storage
- `Buckets.Adapters.S3` - Amazon S3 and S3-compatible services

### Object Lifecycle

`Buckets.Object` structs represent files and have several states:

- **Not stored** (`stored?: false`) - File exists locally but hasn't been uploaded to cloud storage
- **Stored** (`stored?: true`) - File has been uploaded and has a remote location
- **Data loaded** - File data is available in memory or as a local file
- **Data not loaded** - Only metadata is available, data must be fetched from remote storage

## Usage

Now that everything is configured, we can start inserting objects. The simplest possible
way to do this is to upload a file from a path:

```elixir
MyApp.Cloud.insert!("path/to/file.pdf")
```

More likely, you will be storing objects from the result of a file upload:

```elixir
# A controller action that accepts a Plug.Upload from a form.
def file_upload(conn, %{"form" => %{"file" => upload}}) do
  object =
    upload
    |> Buckets.Object.from_upload()
    |> MyApp.Cloud.insert!()

  # Handle object result, i.e. insert into your database.
end
```

Once an object has been stored in a remote bucket, it will have a `:location` set to a
`%Buckets.Location{}` struct, and the `:stored?` field will be `true`. Use the `:path`
field of the location to get the exact path that points to the stored remote object.

Oftentimes, you will need to work with objects that were uploaded. Hopefully, you stored at
minimum the `:path` for the object, though in some cases you will want to store additional
information such as the specific cloud or bucket it was stored in.

Here is how you might load the data for an object that your application had stored:

```elixir
object = MyApp.Storage.get_object!(object_id)

remote_object =
  Buckets.Object.new(object.id, object.filename,
    metadata: object.metadata,
    location: {object.path, MyApp.Cloud}
  )

{:ok, data} = MyApp.Cloud.read(remote_object)
```

## LiveView Direct Uploads

Buckets integrates seamlessly with Phoenix LiveView for direct-to-cloud uploads. This allows users to upload files directly to your cloud storage without going through your server.

### Configuration

To enable LiveView uploads, you must configure the `:uploader` option for your Cloud module:

```elixir
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.S3,
  bucket: "my-uploads",
  # Required for LiveView uploads - use the uploader that matches your adapter
  uploader: "S3",  # Use "GCS" for Google Cloud Storage, "S3" for S3/R2/Spaces/Tigris
  # ... other configuration
```

### Usage in LiveView

```elixir
defmodule MyAppWeb.UploadLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png),
       external: &presign_upload/2,
       progress: &handle_progress/3,
       auto_upload: true
     )}
  end

  def presign_upload(entry, socket) do
    {:ok, upload_config} = MyApp.Cloud.live_upload(entry)
    {:ok, upload_config, socket}
  end

  def handle_progress(_type, entry, socket) do
    if entry.done? do
      %{object: object} =
        consume_uploaded_entry(socket, entry, fn meta ->
          object = Buckets.Object.from_upload({entry, meta})

          # Object is already stored, since we used an external uploader.
          true = object.stored?

          # Persist object data to database, etc.
          {:ok, object}
        end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
```

The `live_upload/2` function returns a map with:
- `:uploader` - The configured uploader type ("S3", "GCS", etc.)
- `:url` - A signed URL for direct upload to the cloud storage

## Dev router

To use the Volume strategy for local development, import the dev router in your own router
module and add the routes for accepting local uploads:

```elixir
if Application.compile_env(:my_app, :dev_routes) do
  import Buckets.Router

  buckets_volume(MyApp.Cloud)
end
```

## Advanced Usage

### Multiple Cloud Modules

For applications that need to use multiple storage backends simultaneously, you can create multiple Cloud modules. Each Cloud module corresponds to a single storage backend:

```elixir
# Local filesystem (for development)
defmodule MyApp.VolumeCloud do
  use Buckets.Cloud, otp_app: :my_app
end

# Google Cloud Storage
defmodule MyApp.GCSCloud do
  use Buckets.Cloud, otp_app: :my_app
end

# Amazon S3
defmodule MyApp.S3Cloud do
  use Buckets.Cloud, otp_app: :my_app
end
```

Configure each Cloud module separately:

```elixir
# Local filesystem
config :my_app, MyApp.VolumeCloud,
  adapter: Buckets.Adapters.Volume,
  bucket: "tmp/buckets_volume",
  base_url: "http://localhost:4000"

# Google Cloud Storage
config :my_app, MyApp.GCSCloud,
  adapter: Buckets.Adapters.GCS,
  bucket: "my-app-production",
  service_account_credentials: System.fetch_env!("GOOGLE_CREDENTIALS")

# Amazon S3
config :my_app, MyApp.S3Cloud,
  adapter: Buckets.Adapters.S3,
  bucket: "my-app-s3-bucket",
  region: "us-east-1",
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")

# Cloudflare R2
config :my_app, MyApp.R2Cloud,
  adapter: Buckets.Adapters.S3,
  provider: :cloudflare,
  endpoint_url: "https://your-account-id.r2.cloudflarestorage.com",
  bucket: "my-bucket",
  access_key_id: "your-r2-access-key",
  secret_access_key: "your-r2-secret-key",
  # R2 automatically uses region: "auto"
  uploader: "S3"

# DigitalOcean Spaces
config :my_app, MyApp.SpacesCloud,
  adapter: Buckets.Adapters.S3,
  provider: :digitalocean,
  bucket: "my-bucket",
  # Defaults to nyc3 region and endpoint
  # region: "nyc3",
  # endpoint_url: "https://nyc3.digitaloceanspaces.com",
  access_key_id: "your-spaces-key",
  secret_access_key: "your-spaces-secret",
  uploader: "S3"

# Tigris
config :my_app, MyApp.TigrisCloud,
  adapter: Buckets.Adapters.S3,
  provider: :tigris,
  bucket: "my-bucket",
  region: "auto",
  # Tigris automatically uses endpoint: "https://fly.storage.tigris.dev"
  access_key_id: "your-tigris-access-key",
  secret_access_key: "your-tigris-secret-key",
  uploader: "S3"
```

Add only the Cloud modules that need supervision to your supervision tree:

```elixir
def start(_type, _args) do
  children = [
    # ... your other processes
    MyApp.GCSCloud,        # Needs supervision for auth servers
    # MyApp.VolumeCloud,   # No supervision needed - would show warning
    # MyApp.S3Cloud,       # No supervision needed - would show warning
    # MyApp.R2Cloud,       # No supervision needed - would show warning
    # MyApp.SpacesCloud    # No supervision needed - would show warning
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Only GCS requires supervision for authentication servers. Volume and S3-based adapters work without any supervised processes.

Then choose the appropriate Cloud module for different use cases:

```elixir
# Store user uploads in S3
user_avatar = MyApp.S3Cloud.insert!(upload)

# Store application assets in GCS
processed_image = MyApp.GCSCloud.insert!(processed_file)

# Store temporary files locally
temp_file = MyApp.VolumeCloud.insert!(temp_data)

# Store CDN assets in R2
cdn_asset = MyApp.R2Cloud.insert!(optimized_image)
```

### Dynamic Cloud Configuration

For multi-tenant applications where cloud configurations are determined at runtime, every Cloud module supports dynamic configuration using the process dictionary. This approach is similar to Ecto's dynamic repositories.

**Usage**:

There are two ways to use dynamic configuration:

#### 1. Scoped Configuration (like Ecto transactions)

Use `with_config/2` for temporary configuration:

```elixir
# Define the runtime configuration
config = [
  adapter: Buckets.Adapters.S3,
  bucket: "user-#{user.id}-bucket",
  access_key_id: user.aws_access_key,
  secret_access_key: user.aws_secret_key,
  region: "us-east-1"
]

# Execute operations with the dynamic config
object = MyApp.Cloud.with_config(config, fn ->
  MyApp.Cloud.insert!("file.pdf")
end)
```

#### 2. Process-Local Configuration (like Ecto.Repo.put_dynamic_repo)

Use `put_dynamic_config/1` for persistent configuration in the current process:

```elixir
# Set dynamic config for this process
:ok = MyApp.Cloud.put_dynamic_config([
  adapter: Buckets.Adapters.GCS,
  bucket: "tenant-#{tenant.id}-bucket",
  service_account_credentials: tenant.gcs_credentials
])

# All subsequent operations use the dynamic config
{:ok, object1} = MyApp.Cloud.insert("file1.pdf")
{:ok, object2} = MyApp.Cloud.insert("file2.pdf")
```

Dynamic configuration is perfect for:
- Multi-tenant applications where each tenant has their own storage
- Applications that need runtime-configurable storage
- Testing with temporary cloud configurations
- Isolating storage per user or organization

**Note**: Auth servers (for GCS) are automatically started and cached per-process as needed. You don't need any special configuration or supervision setup for dynamic clouds.

## Error Handling

Buckets provides two versions of most operations: one that returns `{:ok, result}` or `{:error, reason}` tuples, and a bang (!) version that returns the result or raises an exception.

### Common Errors

1. **Configuration Errors**
   - Missing required configuration options
   - Invalid credentials
   - Non-existent buckets

2. **Network Errors**
   - Connection timeouts
   - Network failures
   - Service unavailability

3. **Permission Errors**
   - Insufficient permissions
   - Invalid or expired credentials
   - Access denied to specific resources

4. **File Errors**
   - File not found (`:not_found`)
   - File too large
   - Invalid file format

### Error Handling Examples

```elixir
# Using pattern matching with tuple returns
case MyApp.Cloud.insert(upload) do
  {:ok, object} ->
    # Handle success
    IO.puts("File uploaded: #{object.filename}")

  {:error, :not_found} ->
    # Handle specific error
    IO.puts("File not found")

  {:error, reason} ->
    # Handle general error
    Logger.error("Upload failed: #{inspect(reason)}")
end

# Using bang functions with try/rescue
try do
  object = MyApp.Cloud.insert!(upload)
  IO.puts("File uploaded: #{object.filename}")
rescue
  e in RuntimeError ->
    Logger.error("Upload failed: #{e.message}")
end

# Loading objects with error handling
case MyApp.Cloud.load(object) do
  {:ok, loaded_object} ->
    # Object data is now available
    data = Buckets.Object.read!(loaded_object)

  {:error, :not_found} ->
    # Object doesn't exist in remote storage
    Logger.warn("Object not found in storage")

  {:error, reason} ->
    Logger.error("Failed to load object: #{inspect(reason)}")
end
```

### Adapter-Specific Errors

Different adapters may return specific error types:

- **GCS**: Authentication errors, quota exceeded, bucket not found
- **S3**: Access denied, region mismatch, signature errors
- **Volume**: File system errors, permission denied, disk full

Always check your adapter's documentation for specific error conditions.

## Testing

By default, tests that interact with live services are excluded. To run them,
you must explicitly include them in the test command:

```sh
# Run all live tests
mix test --include live

# Run live tests for specific adapters
mix test --include live_gcs           # Google Cloud Storage
mix test --include live_s3            # Amazon S3
mix test --include live_cloudflare_r2 # Cloudflare R2
mix test --include live_digitalocean  # DigitalOcean Spaces
mix test --include live_tigris        # Tigris

# Run live tests for multiple adapters
mix test --include live_gcs --include live_s3
```
