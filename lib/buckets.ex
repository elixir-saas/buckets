defmodule Buckets do
  @moduledoc """
  Provides a generic interface for uploading files to buckets hosted by
  different cloud providers.
  """

  @doc """
  Delegates a `put/3` function call to the configured `:adapter`.
  """
  def put(%Buckets.Object{} = object, remote_path, config) do
    {adapter, config} = Keyword.pop!(config, :adapter)
    adapter.put(object, remote_path, config)
  end

  @doc """
  Delegates a `get/2` function call to the configured `:adapter`.
  """
  def get(remote_path, config) do
    {adapter, config} = Keyword.pop!(config, :adapter)
    adapter.get(remote_path, config)
  end

  @doc """
  Delegates a `url/2` function call to the configured `:adapter`.
  """
  def url(remote_path, config) do
    {adapter, config} = Keyword.pop!(config, :adapter)
    adapter.url(remote_path, config)
  end

  @doc """
  Delegates a `delete/2` function call to the configured `:adapter`.
  """
  def delete(remote_path, config) do
    {adapter, config} = Keyword.pop!(config, :adapter)
    adapter.delete(remote_path, config)
  end
end
