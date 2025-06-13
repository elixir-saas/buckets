defmodule Buckets.Adapter do
  @callback validate_config(Keyword.t()) ::
              {:ok, Keyword.t()} | {:error, term()}

  @callback put(Buckets.Object.t(), binary(), Keyword.t()) ::
              {:ok, map()} | {:error, term()}

  @callback get(binary(), Keyword.t()) ::
              {:ok, binary()} | {:error, term()}

  @callback url(binary(), Keyword.t()) ::
              {:ok, Buckets.SignedURL.t()}

  @callback delete(binary(), Keyword.t()) ::
              {:ok, map()} | {:error, term()}

  ## Helpers

  @spec validate_required(Keyword.t(), list()) :: {:ok, Keyword.t()} | {:error, list()}
  def validate_required(config, required) do
    missing =
      required
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce([], fn key, missing ->
        if Keyword.has_key?(config, key), do: missing, else: [key | missing]
      end)

    if missing == [], do: {:ok, config}, else: {:error, Enum.reverse(missing)}
  end
end
