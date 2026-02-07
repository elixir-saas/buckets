defmodule Buckets do
  @version Mix.Project.config()[:version]

  @moduledoc """
  Cloud-agnostic file storage for Elixir with Phoenix integration.

  Buckets provides a unified API for working with file storage across different
  cloud providers. Whether you're using local filesystem storage for development,
  Google Cloud Storage, Amazon S3, or other S3-compatible providers, Buckets
  offers a consistent interface with powerful features.

  ## Features

  - **Multiple Storage Adapters** - Support for filesystem, Google Cloud Storage,
    Amazon S3, and S3-compatible providers (Cloudflare R2, DigitalOcean Spaces, Tigris)
  - **Direct Uploads** - Upload files directly from browsers to cloud storage,
    bypassing your Phoenix server
  - **Signed URLs** - Generate time-limited, secure URLs for private files
  - **LiveView Integration** - Seamless integration with Phoenix LiveView's
    file upload functionality
  - **Dynamic Configuration** - Switch storage providers at runtime for
    multi-tenant applications
  - **Development Tools** - Built-in router for local file uploads/downloads
    during development
  - **Telemetry** - Comprehensive instrumentation for monitoring and debugging

  ## Quick Start

  1. Add `buckets` to your dependencies:

      ```elixir
      def deps do
        [{:buckets, "~> #{@version}"}]
      end
      ```

  2. Create a Cloud module:

      ```elixir
      defmodule MyApp.Cloud do
        use Buckets.Cloud, otp_app: :my_app
      end
      ```

  3. Configure your adapter:

      ```elixir
      # config/dev.exs
      config :my_app, MyApp.Cloud,
        adapter: Buckets.Adapters.Volume,
        bucket: "priv/uploads",
        base_url: "http://localhost:4000"
      ```

  4. Upload files:

      ```elixir
      # From a Plug.Upload or Phoenix.LiveView.UploadEntry
      {:ok, object} = MyApp.Cloud.insert(upload)

      # From a file path
      object = Buckets.Object.from_file("photo.jpg")
      {:ok, stored} = MyApp.Cloud.insert(object)

      # Generate a signed URL
      {:ok, url} = MyApp.Cloud.url(stored, expires: 3600)
      ```

  ## Storage Adapters

  Buckets includes these built-in adapters:

  - `Buckets.Adapters.Volume` - Local filesystem storage
  - `Buckets.Adapters.S3` - Amazon S3 and S3-compatible services
  - `Buckets.Adapters.GCS` - Google Cloud Storage

  See the adapter modules for specific configuration options.

  ## Next Steps

  - See `Buckets.Cloud` for the high-level API
  - See `Buckets.Object` for working with file objects
  - Read the [Getting Started](guides/introduction/getting-started.html) guide
  - Learn about [Direct Uploads with LiveView](guides/howtos/direct-uploads-liveview.html)
  """

  alias Buckets.Telemetry

  @doc """
  Delegates a `put/3` function call to the configured `:adapter`.
  """
  def put(%Buckets.Object{} = object, remote_path, config) do
    {adapter, config} = Keyword.pop!(config, :adapter)

    metadata = %{
      adapter: adapter,
      filename: object.filename,
      path: remote_path,
      content_type: object.metadata[:content_type]
    }

    Telemetry.span([:buckets, :adapter, :put], metadata, fn ->
      adapter.put(object, remote_path, config)
    end)
  end

  @doc """
  Delegates a `get/2` function call to the configured `:adapter`.
  """
  def get(remote_path, config) do
    {adapter, config} = Keyword.pop!(config, :adapter)

    metadata = %{
      adapter: adapter,
      path: remote_path
    }

    Telemetry.span([:buckets, :adapter, :get], metadata, fn ->
      adapter.get(remote_path, config)
    end)
  end

  @doc """
  Delegates a `url/2` function call to the configured `:adapter`.
  """
  def url(remote_path, config) do
    {adapter, config} = Keyword.pop!(config, :adapter)

    metadata = %{
      adapter: adapter,
      path: remote_path
    }

    Telemetry.span([:buckets, :adapter, :url], metadata, fn ->
      adapter.url(remote_path, config)
    end)
  end

  @doc """
  Delegates a `copy/3` function call to the configured `:adapter`.
  """
  def copy(source_path, destination_path, config) do
    {adapter, config} = Keyword.pop!(config, :adapter)

    metadata = %{
      adapter: adapter,
      source_path: source_path,
      destination_path: destination_path
    }

    Telemetry.span([:buckets, :adapter, :copy], metadata, fn ->
      adapter.copy(source_path, destination_path, config)
    end)
  end

  @doc """
  Delegates a `delete/2` function call to the configured `:adapter`.
  """
  def delete(remote_path, config) do
    {adapter, config} = Keyword.pop!(config, :adapter)

    metadata = %{
      adapter: adapter,
      path: remote_path
    }

    Telemetry.span([:buckets, :adapter, :delete], metadata, fn ->
      adapter.delete(remote_path, config)
    end)
  end
end
