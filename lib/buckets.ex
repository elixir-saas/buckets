defmodule Buckets do
  @moduledoc """
  Provides a generic interface for uploading files to buckets hosted by
  different cloud providers.
  """

  def put(%Buckets.Object{} = object, remote_path, config) do
    {strategy, config} = Keyword.pop!(config, :strategy)
    strategy.put(object, remote_path, config)
  end

  def get(remote_path, config) do
    {strategy, config} = Keyword.pop!(config, :strategy)
    strategy.get(remote_path, config)
  end

  def url(remote_path, config) do
    {strategy, config} = Keyword.pop!(config, :strategy)
    strategy.url(remote_path, config)
  end

  def delete(remote_path, config) do
    {strategy, config} = Keyword.pop!(config, :strategy)
    strategy.delete(remote_path, config)
  end
end
