defmodule Buckets.Adapter do
  @moduledoc """
  Behaviour definition for Buckets storage adapters.

  An adapter implements the storage operations for a specific backend (filesystem,
  S3, GCS, etc.). All adapters must implement the required callbacks to handle
  file operations like uploading, downloading, and generating signed URLs.

  ## Implementing an Adapter

  To create a new adapter, implement this behaviour:

      defmodule MyApp.CustomAdapter do
        @behaviour Buckets.Adapter

        @impl true
        def validate_config(config) do
          # Validate and normalize configuration
        end

        @impl true
        def put(object, remote_path, config) do
          # Upload object to storage
        end

        @impl true
        def get(remote_path, config) do
          # Download data from storage
        end

        @impl true
        def url(remote_path, config) do
          # Generate signed URL for direct access
        end

        @impl true
        def delete(remote_path, config) do
          # Delete object from storage
        end

        # Optional: Only if adapter needs supervised processes
        @impl true
        def child_spec(config, cloud_module) do
          # Return supervisor child specification
        end
      end

  ## Configuration

  Each adapter defines its own configuration options, but common ones include:
  - `:bucket` - The storage bucket/container name
  - `:path` - Base path within the bucket
  - `:uploader` - Uploader type for LiveView direct uploads

  ## Supervised Processes

  Some adapters (like GCS) require background processes for authentication or
  connection management. These adapters should implement the optional `child_spec/2`
  callback. Adapters that don't need supervision (like Volume, S3) should not
  implement this callback.
  """

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

  @doc """
  Validates and normalizes adapter configuration.

  This callback is called during Cloud module initialization to ensure the
  configuration is valid. It should:
  - Validate required options are present
  - Set default values for optional options
  - Normalize configuration format
  - Return an error tuple with invalid/missing keys if validation fails

  ## Examples

      def validate_config(config) do
        config
        |> Keyword.validate([:adapter, :bucket, :path, :uploader])
        |> case do
          {:ok, config} -> validate_required(config, [:bucket])
          error -> error
        end
      end
  """
  @callback validate_config(Keyword.t()) ::
              {:ok, Keyword.t()} | {:error, term()}

  @doc """
  Uploads an object to the storage backend.

  Takes a `Buckets.Object` struct containing the data to upload, the remote
  path where it should be stored, and the adapter configuration.

  Should return `{:ok, metadata}` on success where metadata is adapter-specific,
  or `{:error, reason}` on failure.

  ## Examples

      def put(object, "uploads/file.pdf", config) do
        # Upload logic here
        {:ok, %{etag: "abc123", version: "v1"}}
      end
  """
  @callback put(Buckets.Object.t(), binary(), Keyword.t()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Downloads data from the storage backend.

  Takes the remote path of the object and the adapter configuration.
  Returns the binary data on success or an error tuple on failure.

  ## Examples

      def get("uploads/file.pdf", config) do
        case download_file(path, config) do
          {:ok, data} -> {:ok, data}
          {:error, :not_found} -> {:error, :not_found}
          {:error, reason} -> {:error, reason}
        end
      end
  """
  @callback get(binary(), Keyword.t()) ::
              {:ok, binary()} | {:error, term()}

  @doc """
  Generates a signed URL for direct access to an object.

  Takes the remote path and configuration (which may include options like
  `:expires_in` for controlling URL expiration).

  Returns a `Buckets.SignedURL` struct containing the URL and metadata.

  ## Options

  - `:expires_in` - URL expiration time in seconds (adapter-specific default)
  - `:for_upload` - Generate a URL for uploading instead of downloading

  ## Examples

      def url("uploads/file.pdf", config) do
        signed_url = generate_signed_url(path, config)
        {:ok, %Buckets.SignedURL{url: signed_url, expires_at: expiry}}
      end
  """
  @callback url(binary(), Keyword.t()) ::
              {:ok, Buckets.SignedURL.t()}

  @doc """
  Deletes an object from the storage backend.

  Takes the remote path of the object to delete and the adapter configuration.
  Returns `{:ok, metadata}` on success or `{:error, reason}` on failure.

  ## Examples

      def delete("uploads/file.pdf", config) do
        case delete_object(path, config) do
          :ok -> {:ok, %{}}
          {:error, reason} -> {:error, reason}
        end
      end
  """
  @callback delete(binary(), Keyword.t()) ::
              {:ok, map()} | {:error, term()}

  @optional_callbacks child_spec: 2

  ## Helpers

  @doc """
  Validates that required configuration keys are present.

  A helper function for adapters to use in their `validate_config/1` callback
  to ensure all required configuration options are provided.

  ## Parameters

  - `config` - The configuration keyword list to validate
  - `required` - List of required keys that must be present in the config

  ## Returns

  - `{:ok, config}` - All required keys are present
  - `{:error, missing_keys}` - List of keys that are missing from config

  ## Examples

      def validate_config(config) do
        with {:ok, config} <- Keyword.validate(config, @allowed_options),
             {:ok, config} <- validate_required(config, [:bucket, :access_key]) do
          {:ok, config}
        end
      end

  ## Implementation Note

  The function filters out `nil` values from the required list, allowing
  conditional validation based on other configuration options.
  """
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
