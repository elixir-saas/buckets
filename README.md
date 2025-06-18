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
- [x] Cloudflare R2 ([`Buckets.Adapters.S3` with `provider: :cloudflare`](./lib/buckets/adapters/s3.ex))
- [x] DigitalOcean Spaces ([`Buckets.Adapters.S3` with `provider: :digitalocean`](./lib/buckets/adapters/s3.ex))
- [x] Tigris ([`Buckets.Adapters.S3` with `provider: :tigris`](./lib/buckets/adapters/s3.ex))

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
    {:buckets, "~> 1.0.0-rc.1"}
  ]
end
```

Full documentation at <https://hexdocs.pm/buckets>.

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

## Getting started

### 1. Create your Cloud module

Start by creating a single Cloud module for your application:

```elixir
defmodule MyApp.Cloud do
  use Buckets.Cloud, otp_app: :my_app
end
```

### 2. Configure your Cloud module

Configure your Cloud module with different adapters for different environments:

```elixir
# Development - local filesystem
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.Volume,
  bucket: "tmp/buckets_volume",
  base_url: "http://localhost:4000"

# Production - Google Cloud Storage
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.GCS,
  bucket: "my-app-production",
  service_account_credentials: System.fetch_env!("GOOGLE_CREDENTIALS")

# Alternative production - Amazon S3
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.S3,
  bucket: "my-app-production",
  region: "us-east-1",
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
```

### 3. Add to your supervision tree (if needed)

**Only add your Cloud module to supervision if it uses an adapter that needs background processes.**

Some adapters (like GCS) require authentication servers, while others (like Volume, S3) work without supervision:

```elixir
def start(_type, _args) do
  children = [
    # ... your other processes
    # Only add if using GCS adapter - Volume/S3 don't need supervision
    MyApp.Cloud  # Add this line only for GCS
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

If you add a Cloud module that doesn't need supervision, you'll see a warning message suggesting you remove it to avoid unnecessary overhead.

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
    location: {object.path, {:module, MyApp.Cloud}}
  )

{:ok, data} = MyApp.Cloud.read(remote_object)
```

## Dev router

To use the Volume strategy for local development, import the dev router in your own router
module and add the routes for accepting local uploads:

```elixir
if Application.compile_env(:my_app, :dev_routes) do
  import Buckets.Router

  buckets_volume(path: "tmp/buckets_volume")
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
  provider: :cloudflare_r2,
  endpoint_url: "https://your-account-id.r2.cloudflarestorage.com",
  bucket: "my-bucket",
  access_key_id: "your-r2-access-key",
  secret_access_key: "your-r2-secret-key"

# DigitalOcean Spaces
config :my_app, MyApp.SpacesCloud,
  adapter: Buckets.Adapters.S3,
  provider: :digitalocean,
  bucket: "my-bucket",
  access_key_id: "your-spaces-key",
  secret_access_key: "your-spaces-secret"
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

### Dynamic Cloud Modules

For multi-tenant applications where each user has their own cloud storage credentials, you can create dynamic cloud instances at runtime.

**Setup Required**: Dynamic clouds need additional supervision. Add these to your application's supervision tree:

```elixir
def start(_type, _args) do
  children = [
    # Your core application processes
    MyApp.Repo,
    MyAppWeb.Endpoint,

    # Required for dynamic clouds (add only if using dynamic clouds)
    {Buckets.Cloud.DynamicSupervisor, []}
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

**Usage**:

```elixir
# Create a dynamic cloud for a specific user
user_config = [
  adapter: Buckets.Adapters.S3,
  bucket: "user-#{user.id}-bucket",
  access_key_id: user.aws_access_key,
  secret_access_key: user.aws_secret_key,
  region: "us-east-1"
]

# For GCS, you must include an :id field for auth server lookup
gcs_config = [
  adapter: Buckets.Adapters.GCS,
  id: "user_#{user.id}",  # Required for GCS dynamic configs
  bucket: "user-#{user.id}-bucket",
  service_account_credentials: user.gcs_credentials
]

{:ok, user_cloud_pid} = Buckets.Cloud.start_dynamic(user_config)

# Use it exactly like a static cloud
{:ok, object} = Buckets.Cloud.Dynamic.insert(user_cloud_pid, upload)
{:ok, loaded_object} = Buckets.Cloud.Dynamic.load(user_cloud_pid, object)
```

You can also register dynamic clouds by name for easy lookup:

```elixir
# Register a dynamic cloud by user ID
:ok = Buckets.Cloud.register_dynamic("user_#{user.id}", user_config)

# Later, get the cloud by name and use it
{:ok, user_cloud} = Buckets.Cloud.get_dynamic("user_#{user.id}")
{:ok, object} = Buckets.Cloud.Dynamic.insert(user_cloud, "file.pdf")
```

Clean up dynamic clouds when no longer needed:

```elixir
# Stop by pid
:ok = Buckets.Cloud.stop_dynamic(user_cloud_pid)

# Stop by name
:ok = Buckets.Cloud.stop_dynamic("user_#{user.id}")
```

Dynamic clouds are perfect for:
- Multi-tenant applications where each tenant has their own storage
- Applications that need runtime-configurable storage
- Testing with temporary cloud configurations
- Isolating storage per user or organization

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
