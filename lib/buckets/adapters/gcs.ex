defmodule Buckets.Adapters.GCS do
  @moduledoc """
  Google Cloud Storage adapter for Buckets.

  This adapter provides a native implementation for GCS operations using only
  the `:req` HTTP client, without dependencies on `:google_api_storage`, `:gcs_signed_url`, or `:goth`.

  ## Setup

  To use this adapter, you need to start your Cloud module in your application's
  supervision tree to enable automatic token caching and refresh:

      children = [
        # ... your other processes
        MyApp.Cloud
      ]

      Supervisor.start_link(children, opts)

  The Cloud module will automatically start the required authentication processes for GCS locations.

  The supervisor will automatically manage authentication tokens for each unique set of
  service account credentials, refreshing them before they expire.

  ## Configuration

  You can configure GCS locations using either service account credentials as a JSON string
  or by providing a path to a service account JSON file:

      config :my_app, MyCloud,
        locations: [
          gcs_direct: [
            adapter: Buckets.Adapters.GCS,
            bucket: "my-bucket",
            path: "uploads",
            service_account_credentials: System.fetch_env!("GOOGLE_CREDENTIALS")
          ],
          gcs_from_file: [
            adapter: Buckets.Adapters.GCS,
            bucket: "my-bucket",
            path: "uploads",
            service_account_path: "path/to/service-account.json"
          ]
        ]

  The `:service_account_credentials` option accepts a JSON string, making it easy to pass
  credentials via environment variables:

      service_account_credentials: System.get_env("GCS_SERVICE_ACCOUNT_JSON")

  ## Performance

  This implementation automatically caches and refreshes Google Cloud access tokens,
  significantly reducing latency compared to generating new tokens for each request.
  Tokens are refreshed 5 minutes before expiration to ensure uninterrupted service.
  """

  @behaviour Buckets.Adapter

  require Logger

  alias Buckets.Object
  alias Buckets.Adapters.GCS.Auth
  alias Buckets.Adapters.GCS.Signature
  alias Buckets.Adapters.GCS.AuthServer

  @impl true
  def child_spec(_config, cloud_module) do
    %{
      id: {AuthServer, cloud_module},
      start: {AuthServer, :start_link, [[cloud: cloud_module]]},
      restart: :permanent
    }
  end

  @impl true
  def validate_config(config) do
    validate_result =
      Keyword.validate(config, [
        :adapter,
        :bucket,
        :path,
        :uploader,
        :service_account_path,
        :service_account_credentials
      ])

    with {:ok, config} <- validate_result do
      if config[:service_account_path] || config[:service_account_credentials] do
        Buckets.Adapter.validate_required(config, [:bucket])
      else
        {:error, [:service_account_path, :service_account_credentials]}
      end
    end
  end

  @impl true
  def put(%Buckets.Object{} = object, remote_path, config) do
    bucket = Keyword.fetch!(config, :bucket)

    data = Object.read!(object)
    content_type = object.metadata[:content_type] || "application/octet-stream"

    with {:ok, access_token} <- get_access_token(config) do
      do_put(access_token, bucket, remote_path, data, content_type)
    end
  end

  @impl true
  def get(remote_path, config) do
    bucket = Keyword.fetch!(config, :bucket)

    with {:ok, access_token} <- get_access_token(config) do
      do_get(access_token, bucket, remote_path)
    end
  end

  @doc """
  Gets a signed URL for temporarily delegating access to an object in a bucket.

  ## Errors

      * 403 PERMISSION_DENIED: Permission 'iam.serviceAccounts.signBlob' denied on resource
        (or it may not exist). Make sure the authorized SA has role roles/iam.serviceAccountTokenCreator
        on the SA passed in the URL.

      * 403 PERMISSION_DENIED: IAM Service Account Credentials API has not been used in project {project_id}
        before or it is disabled. Enable it by visiting {url} then retry. If you enabled this API recently,
        wait a few minutes for the action to propagate to our systems and retry. Make sure the authorized SA
        has role roles/iam.serviceAccountTokenCreator on the SA passed in the URL."

  """
  @impl true
  def url(remote_path, config) do
    bucket = Keyword.fetch!(config, :bucket)

    with {:ok, credentials} <- Auth.get_credentials(config) do
      opts =
        if config[:for_upload] == true do
          [verb: "PUT", expires: 900]
        else
          [verb: "GET", expires: 3600]
        end

      opts = Keyword.merge(opts, config[:gcs_signed_url] || [])

      case Signature.generate_v4(credentials, bucket, remote_path, opts) do
        {:ok, signed_url} ->
          location = %Buckets.Location{path: remote_path, config: config}
          {:ok, %Buckets.SignedURL{url: signed_url, location: location}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @impl true
  def delete(remote_path, config) do
    bucket = Keyword.fetch!(config, :bucket)

    with {:ok, access_token} <- get_access_token(config) do
      do_delete(access_token, bucket, remote_path)
    end
  end

  ## Private

  defp get_access_token(config) do
    case config[:__auth_server_pid__] do
      pid when is_pid(pid) ->
        # Use existing auth server (from dynamic config)
        AuthServer.get_token(pid)

      nil ->
        # No auth server - call Auth.get_credentials directly
        case Auth.get_credentials(config) do
          {:ok, credentials} ->
            Auth.get_access_token(credentials)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp do_put(access_token, bucket, object_name, data, content_type) do
    url = "https://storage.googleapis.com/upload/storage/v1/b/#{bucket}/o"

    headers = [
      {"authorization", "Bearer #{access_token}"},
      {"content-type", content_type}
    ]

    params = [
      {"uploadType", "media"},
      {"name", object_name}
    ]

    case Req.post(url, body: data, headers: headers, params: params) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp do_get(access_token, bucket, object_name) do
    url =
      "https://storage.googleapis.com/storage/v1/b/#{bucket}/o/#{URI.encode(object_name, &URI.char_unreserved?/1)}"

    headers = [
      {"authorization", "Bearer #{access_token}"}
    ]

    params = [{"alt", "media"}]

    case Req.get(url, headers: headers, params: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp do_delete(access_token, bucket, object_name) do
    url =
      "https://storage.googleapis.com/storage/v1/b/#{bucket}/o/#{URI.encode(object_name, &URI.char_unreserved?/1)}"

    headers = [
      {"authorization", "Bearer #{access_token}"}
    ]

    case Req.delete(url, headers: headers) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, %{}}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end
end
