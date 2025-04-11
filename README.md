<p align="center">
  <img src="priv/logo.png" height="150" />
</p>

---

# Buckets

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `buckets` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:buckets, "~> 0.2.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/buckets>.

## Testing

By default, tests that interact with live services are excluded. To run them,
you must explicitly include them in the test command:

```sh
# Run all live tests
mix test --include live

# Run just live tests for google cloud storage
mix test --include live_gcs
```
