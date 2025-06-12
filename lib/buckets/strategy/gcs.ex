defmodule Buckets.Strategy.GCS do
  @behaviour Buckets.Strategy

  require Logger

  alias GoogleApi.Storage.V1.Api.Objects
  alias GoogleApi.Storage.V1.Model.Object

  @impl true
  def put(%Buckets.Object{data: {:file, path}} = object, remote_path, config) do
    bucket = Keyword.fetch!(config, :bucket)
    goth_server = Keyword.fetch!(config, :goth_server)

    metadata = %Object{
      name: remote_path,
      contentType: object.metadata.content_type
    }

    with {:ok, conn} <- auth(goth_server),
         {:ok, response} <-
           Objects.storage_objects_insert_simple(conn, bucket, "multipart", metadata, path) do
      {:ok, response}
    else
      error -> handle_error(error)
    end
  end

  @impl true
  def get(remote_path, config) do
    bucket = Keyword.fetch!(config, :bucket)
    goth_server = Keyword.fetch!(config, :goth_server)

    with {:ok, conn} <- auth(goth_server),
         {:ok, %{status: 200, body: data}} <-
           Objects.storage_objects_get(conn, bucket, remote_path, [alt: "media"], []) do
      {:ok, data}
    else
      error -> handle_error(error)
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
    goth_server = Keyword.fetch!(config, :goth_server)
    service_account = Keyword.fetch!(config, :service_account)

    case Goth.fetch(goth_server) do
      {:ok, %{token: access_token}} ->
        oauth_config = %GcsSignedUrl.SignBlob.OAuthConfig{
          service_account: service_account,
          access_token: access_token
        }

        opts =
          if config[:for_upload] == true do
            [verb: "PUT", expires: 900]
          else
            [expires: 60]
          end

        GcsSignedUrl.generate_v4(
          oauth_config,
          bucket,
          remote_path,
          Keyword.merge(opts, config[:gcs_signed_url] || [])
        )
        |> case do
          {:ok, signed_url} ->
            location = %Buckets.Location{path: remote_path, config: config}
            {:ok, %Buckets.SignedURL{url: signed_url, location: location}}

          {:error, reason} ->
            {:error, reason}
        end

      error ->
        handle_error(error)
    end
  end

  @impl true
  def delete(remote_path, config) do
    bucket = Keyword.fetch!(config, :bucket)
    goth_server = Keyword.fetch!(config, :goth_server)

    with {:ok, conn} <- auth(goth_server),
         {:ok, %{status: 204} = response} <-
           Objects.storage_objects_delete(conn, bucket, remote_path) do
      {:ok, response}
    else
      error -> handle_error(error)
    end
  end

  ## Private

  defp auth(goth_server) do
    with {:ok, token} <- Goth.fetch(goth_server) do
      {:ok, GoogleApi.Storage.V1.Connection.new(token.token)}
    end
  end

  defp handle_error({:error, %Tesla.Env{status: 404, body: body}}) do
    {:error, body}
  end

  defp handle_error({:error, %Tesla.Env{status: 500, body: body}}) do
    {:error, Jason.decode!(body)}
  end
end
