# Multi-Cloud Setup

This guide explains how to use multiple cloud storage providers simultaneously in your application.

## Why Multi-Cloud?

Multi-cloud setups are useful for:
- **Geographic distribution** - Store files closer to users
- **Cost optimization** - Use the most cost-effective provider for each use case
- **Redundancy** - Failover between providers
- **Compliance** - Meet data residency requirements
- **Migration** - Gradually move between providers

## Basic Multi-Cloud Setup

### 1. Define Multiple Cloud Modules

```elixir
# For local development
defmodule MyApp.LocalCloud do
  use Buckets.Cloud, otp_app: :my_app
end

# For user uploads
defmodule MyApp.S3Cloud do
  use Buckets.Cloud, otp_app: :my_app
end

# For backups and archives
defmodule MyApp.GCSCloud do
  use Buckets.Cloud, otp_app: :my_app
end

# For CDN assets
defmodule MyApp.R2Cloud do
  use Buckets.Cloud, otp_app: :my_app
end
```

### 2. Configure Each Cloud

```elixir
# config/dev.exs
config :my_app, MyApp.LocalCloud,
  adapter: Buckets.Adapters.Volume,
  bucket: "tmp/local_storage",
  base_url: "http://localhost:4000"

# config/config.exs or runtime.exs
config :my_app, MyApp.S3Cloud,
  adapter: Buckets.Adapters.S3,
  bucket: System.get_env("S3_BUCKET"),
  region: "us-east-1",
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")

config :my_app, MyApp.GCSCloud,
  adapter: Buckets.Adapters.GCS,
  bucket: System.get_env("GCS_BUCKET"),
  service_account_credentials: System.get_env("GOOGLE_CREDENTIALS")

config :my_app, MyApp.R2Cloud,
  adapter: Buckets.Adapters.S3,
  provider: :cloudflare,
  bucket: System.get_env("R2_BUCKET"),
  endpoint_url: System.get_env("R2_ENDPOINT"),
  access_key_id: System.get_env("R2_ACCESS_KEY"),
  secret_access_key: System.get_env("R2_SECRET_KEY")
```

### 3. Add to Supervision Tree

```elixir
def start(_type, _args) do
  children = [
    # ... other processes
    MyApp.GCSCloud,  # Only GCS needs supervision
    # S3, R2, and Volume don't need supervision
  ]
  
  Supervisor.start_link(children, opts)
end
```

## Usage Patterns

### Content-Based Routing

Route files to different clouds based on content:

```elixir
defmodule MyApp.Storage do
  def store_file(upload) do
    cloud = determine_cloud(upload)
    object = Buckets.Object.from_upload(upload)
    cloud.insert(object)
  end
  
  defp determine_cloud(upload) do
    case upload.content_type do
      "image/" <> _ -> MyApp.R2Cloud      # Images to CDN
      "video/" <> _ -> MyApp.S3Cloud      # Videos to S3
      "application/pdf" -> MyApp.GCSCloud # Documents to GCS
      _ -> MyApp.S3Cloud                  # Default to S3
    end
  end
end
```

### Geographic Distribution

Store files in the closest region:

```elixir
defmodule MyApp.GeoStorage do
  @clouds %{
    "US" => MyApp.USCloud,
    "EU" => MyApp.EUCloud,
    "ASIA" => MyApp.AsiaCloud
  }
  
  def store_for_user(upload, user) do
    cloud = @clouds[user.region] || MyApp.USCloud
    object = Buckets.Object.from_upload(upload)
    cloud.insert(object)
  end
end
```

## Cross-Cloud Operations

### Copying Between Clouds

```elixir
defmodule MyApp.CloudSync do
  def copy_object(object, from_cloud, to_cloud) do
    # Load from source
    {:ok, loaded} = from_cloud.load(object)
    
    # Insert to destination
    {:ok, copied} = to_cloud.insert(loaded)
    
    copied
  end
  
  def migrate_bucket(from_cloud, to_cloud) do
    objects = list_all_objects(from_cloud)
    
    objects
    |> Task.async_stream(
      fn object ->
        copy_object(object, from_cloud, to_cloud)
      end,
      max_concurrency: 10,
      timeout: 60_000
    )
    |> Stream.run()
  end
end
```

## Database Design

Store cloud information with your files:

```elixir
defmodule MyApp.Files.File do
  use Ecto.Schema
  
  schema "files" do
    field :filename, :string
    field :cloud_module, :string  # "Elixir.MyApp.S3Cloud"
    field :storage_path, :string
    field :content_type, :string
    field :size, :integer
    field :region, :string
    
    timestamps()
  end
  
  def to_object(%__MODULE__{} = file) do
    cloud = String.to_existing_atom(file.cloud_module)
    
    Buckets.Object.new(
      file.id,
      file.filename,
      location: {file.storage_path, cloud},
      metadata: %{
        content_type: file.content_type,
        content_size: file.size
      }
    )
  end
end
```