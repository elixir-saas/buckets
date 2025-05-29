defmodule Buckets do
  @moduledoc """
  Provides a generic interface for uploading files to buckets hosted by
  different cloud providers.
  """

  @doc """
  Delegates a `put/3` function call to the configured `:strategy`.
  """
  def put(%Buckets.Object{} = object, remote_path, config) do
    {strategy, config} = Keyword.pop!(config, :strategy)
    strategy.put(object, remote_path, config)
  end

  @doc """
  Delegates a `get/2` function call to the configured `:strategy`.
  """
  def get(remote_path, config) do
    {strategy, config} = Keyword.pop!(config, :strategy)
    strategy.get(remote_path, config)
  end

  @doc """
  Delegates a `url/2` function call to the configured `:strategy`.
  """
  def url(remote_path, config) do
    {strategy, config} = Keyword.pop!(config, :strategy)
    strategy.url(remote_path, config)
  end

  @doc """
  Delegates a `delete/2` function call to the configured `:strategy`.
  """
  def delete(remote_path, config) do
    {strategy, config} = Keyword.pop!(config, :strategy)
    strategy.delete(remote_path, config)
  end
end
