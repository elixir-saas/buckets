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
- [x] Cloudflare R2 ([`Buckets.Adapters.S3` with `provider: :cloudflare_r2`](./lib/buckets/adapters/s3.ex))
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
    {:buckets, "~> 1.0.0-rc.0"}
  ]
end
```

Full documentation at <https://hexdocs.pm/buckets>.

## Core Concepts

### Cloud Module

The entrypoint to using Buckets is through a `Cloud`, which you declare in your application. Think of it like an Ecto Repo module, but instead of interfacing with a database, you're interfacing with remote cloud storage. Instead of mapping database rows to schema structs, it maps files to `Buckets.Object` structs.

### Locations and Adapters

- **Locations** are named configurations (like `:local`, `:gcs`, `:production`) that define where and how files are stored
- **Adapters** are the actual storage implementations (`Buckets.Adapters.Volume`, `Buckets.Adapters.GCS`, `Buckets.Adapters.S3`)
- Each location specifies an adapter plus the configuration needed for that storage backend

### Object Lifecycle

`Buckets.Object` structs represent files and have several states:

- **Not stored** (`stored?: false`) - File exists locally but hasn't been uploaded to cloud storage
- **Stored** (`stored?: true`) - File has been uploaded and has a remote location
- **Data loaded** - File data is available in memory or as a local file
- **Data not loaded** - Only metadata is available, data must be fetched from remote storage

## Getting started

### 1. Create your Cloud module

```elixir
defmodule MyApp.Cloud do
  use Buckets.Cloud,
    otp_app: :my_app,
    default_location: :local
end
```

You must configure:

- `:otp_app` - Your application name for reading configuration
- `:default_location` - Which location to use when none is specified

### 2. Configure your locations

Each location requires an `:adapter` and adapter-specific configuration:

```elixir
config :my_app, MyApp.Cloud,
  locations: [
    # Local filesystem (for development)
    local: [
      adapter: Buckets.Adapters.Volume,
      bucket: "tmp/buckets_volume",
      base_url: "http://localhost:4000",
      endpoint: MyAppWeb.Endpoint  # Optional: for signed URL verification
    ],

    # Google Cloud Storage
    gcs: [
      adapter: Buckets.Adapters.GCS,
      bucket: "my-app-production",
      service_account_credentials: System.fetch_env!("GOOGLE_CREDENTIALS")
    ],

    # Alternative: Load GCS credentials from file
    gcs_from_file: [
      adapter: Buckets.Adapters.GCS,
      bucket: "my-app-production",
      service_account_path: "path/to/service-account.json"
    ],

    # Amazon S3
    s3: [
      adapter: Buckets.Adapters.S3,
      bucket: "my-app-production",
      region: "us-east-1",
      access_key_id: "AKIAIOSFODNN7EXAMPLE",
      secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    ]
  ]
```

### 3. Add to your supervision tree

Add your Cloud module to your application's supervision tree (typically in `lib/my_app/application.ex`):

```elixir
def start(_type, _args) do
  children = [
    # ... your other processes
    MyApp.Cloud
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

The Cloud module automatically starts any required authentication processes for your configured adapters (like GCS authentication servers).

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
`%Buckets.Object.Location{}` struct, and the `:stored?` field will be `true`. Use the `:path`
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
    location: {object.path, MyApp.Cloud.config_for(:default)}
  )

{:ok, data} = MyApp.Cloud.read(object)
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
