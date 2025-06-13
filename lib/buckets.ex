defmodule Buckets do
  @moduledoc """
  Provides a generic interface for uploading files to buckets hosted by
  different cloud providers.
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
