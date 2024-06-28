defmodule Buckets.Bucket do
  @type scope() :: binary() | %{id: binary()}

  @callback put(Buckets.Upload.t(), scope(), Keyword.t()) ::
              {:ok, Buckets.Object.t()} | {:error, term}

  @callback get(filename :: String.t(), scope(), Keyword.t()) ::
              {:ok, binary}

  @callback url(filename :: String.t(), scope(), Keyword.t()) ::
              {:ok, Buckets.SignedURL.t()}

  @callback delete(filename :: String.t(), scope(), Keyword.t()) ::
              :ok
end
