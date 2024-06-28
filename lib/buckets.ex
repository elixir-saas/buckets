defmodule Buckets do
  @moduledoc """
  Provides a generic interface for uploading files to buckets hosted by
  different cloud providers.
  """

  def put(%Buckets.Upload{} = upload, scope, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.put(upload, scope, opts)
  end

  def get(filename, scope, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.get(filename, scope, opts)
  end

  def url(filename, scope, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.url(filename, scope, opts)
  end

  def delete(filename, scope, opts) do
    {strategy, opts} = Keyword.pop!(opts, :strategy)
    strategy.delete(filename, scope, opts)
  end
end
