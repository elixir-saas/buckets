defmodule Buckets.Adapter do
  @callback put(Buckets.Object.t(), binary(), Keyword.t()) ::
              {:ok, map()} | {:error, term()}

  @callback get(binary(), Keyword.t()) ::
              {:ok, binary()} | {:error, term()}

  @callback url(binary(), Keyword.t()) ::
              {:ok, Buckets.SignedURL.t()}

  @callback delete(binary(), Keyword.t()) ::
              {:ok, map()} | {:error, term()}
end
