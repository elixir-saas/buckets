# Getting Started

Welcome to Buckets! This guide will walk you through setting up Buckets in your Phoenix application.

## Installation

Add `buckets` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:buckets, "~> 1.0.0-rc.2"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

### 1. Create a Cloud Module

Create a Cloud module in your application:

```elixir
defmodule MyApp.Cloud do
  use Buckets.Cloud, otp_app: :my_app
end
```

### 2. Add to Supervision Tree

Add your Cloud module to your application's supervision tree:

```elixir
def start(_type, _args) do
  children = [
    # ... other children
    MyApp.Cloud
  ]

  Supervisor.start_link(children, opts)
end
```

### 3. Configure Your Adapter

For development with local filesystem:

```elixir
# config/dev.exs
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.Volume,
  bucket: "tmp/buckets",
  base_url: "http://localhost:4000"
```

For production with S3:

```elixir
# config/prod.exs
config :my_app, MyApp.Cloud,
  adapter: Buckets.Adapters.S3,
  bucket: "my-production-bucket",
  region: "us-east-1",
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
```

### 4. Basic Usage

Upload a file:

```elixir
{:ok, object} = MyApp.Cloud.insert("/path/to/file.pdf")
```

Handle file uploads from a form:

```elixir
def create(conn, %{"upload" => upload}) do
  {:ok, object} = MyApp.Cloud.insert(Buckets.Object.from_upload(upload))
  # Save object metadata to database
  # ...
end
```

## Next Steps

- Learn about [Core Concepts](core-concepts.html)
- Explore different [Storage Adapters](../adapters/volume-adapter.html)
- Set up [Direct Uploads with LiveView](../howtos/direct-uploads-liveview.html)