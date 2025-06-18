defmodule Buckets.Adapter do
  @doc """
  Returns a child specification for processes this adapter needs, if any.

  This callback is optional. Adapters that need supervised processes (like GCS
  auth servers) should implement this callback. Adapters that don't need any
  supervised processes (like Volume, S3) can omit this callback entirely.

  When implemented, should return:
  - `child_spec()` - A supervisor child specification
  - `{:error, reason}` - Config is invalid

  Examples:
  - GCS adapter implements this to return auth server child spec
  - Volume/S3 adapters don't implement this callback at all
  """
  @callback child_spec(config :: Keyword.t(), cloud_module :: module()) ::
              Supervisor.child_spec() | {:error, term()}

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

  @optional_callbacks child_spec: 2

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
