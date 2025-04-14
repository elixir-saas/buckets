<p align="center">
  <img src="priv/logo.png" height="250" />
</p>

---

# Buckets

A solution for storing objects in buckets.

Supports:

- [x] File System ([`Buckets.Strategy.Volume`](./lib/buckets/strategy/volume.ex))
- [x] Google Cloud Storage ([`Buckets.Strategy.GCS`](./lib/buckets/strategy/gcs.ex))
- [ ] Amazon S3
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

## Installation

Install by adding `buckets` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:buckets, "~> 0.2.0"}
  ]
end
```

Full documentation at <https://hexdocs.pm/buckets>.

## Testing

By default, tests that interact with live services are excluded. To run them,
you must explicitly include them in the test command:

```sh
# Run all live tests
mix test --include live

# Run just live tests for google cloud storage
mix test --include live_gcs
```
