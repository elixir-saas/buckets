<p align="center">
  <img src="priv/logo.png" height="250" />
</p>

---

# Buckets

A solution for storing objects in buckets.

Supports:

- [x] File System ([`Buckets.Strategy.Volume`](./lib/buckets/strategy/volume.ex))
- [x] Google Cloud Storage ([`Buckets.Strategy.GCS`](./lib/buckets/strategy/gcs.ex))
- [x] Amazon S3
- [ ] DigitalOcean
- [ ] Fly.io Tigris

Features:

- [x] Multi-cloud
- [x] Dynamically configured clouds
- [x] Signed URLs
- [x] Easy Plug uploads
- [x] Easy LiveView direct-to-cloud uploads
- [x] Dev env router
- [ ] Streaming uploads
- [ ] Streaming downloads
- [ ] Telemetry

## Installation

Install by adding `buckets` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:buckets, github: "https://github.com/elixir-saas/buckets"}
  ]
end
```

Full documentation at <https://hexdocs.pm/buckets>.

## Getting started

The entrypoint to using Buckets is through a Cloud module, which you declare in
your application. Think of it like an Ecto Repo module, but instead of interfacing
with a database, you're interfacing with a remote cloud bucket. And instead of
mapping data in rows to schema structs, it maps data in files to Object structs.

Here's how you set up your Cloud module:

```elixir
defmodule MyApp.Cloud do
  use Buckets.Cloud,
    otp_app: :my_app,
    default_location: :local
end
```

Notice that in addition to configuring an `:otp_app`, you also must configure a
`:default_location`. "Locations" are sets of configuration that authenticate your
application to access different buckets. For convenience, a Cloud module has a
default, but a specific location can be specified at any time.

Here's how you can configure locations:

```elixir
config :my_app, MyApp.Cloud,
  locations: [
    local: [
      strategy: Buckets.Strategy.Volume,
      # configure this strategy...
    ],
    gcs: [
      strategy: Buckets.Strategy.GCS,
      # configure this strategy...
    ]
  ]
```

A `:strategy` is required, additional configuration options for each strategy can be
found in the docs for the strategy module itself.

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

# Run just live tests for google cloud storage
mix test --include live_gcs
```
