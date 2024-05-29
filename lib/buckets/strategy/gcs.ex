defmodule Buckets.Strategy.GCS do
  @behaviour Buckets.Bucket

  alias Buckets.Util

  alias GoogleApi.Storage.V1.Api.Objects
  alias GoogleApi.Storage.V1.Model.Object

  @impl true
  def put(%Buckets.Upload{} = upload, scope, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    path = Keyword.get(opts, :path, "")
    goth_server = Keyword.fetch!(opts, :goth_server)

    object_id = Util.object_id(scope)
    object_path = Util.build_object_path(path, object_id, upload.filename)

    metadata = %Object{
      name: object_path,
      contentType: upload.content_type
    }

    with {:ok, conn} <- auth(goth_server),
         {:ok, object} <-
           Objects.storage_objects_insert_simple(conn, bucket, "multipart", metadata, upload.path) do
      {:ok,
       %Buckets.Object{
         filename: upload.filename,
         content_type: upload.content_type,
         object_url: object.mediaLink,
         object_path: object_path
       }}
    else
      {:error, %Tesla.Env{body: body}} ->
        {:error, Jason.decode!(body)}
    end
  end

  @impl true
  def get(filename, scope, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    path = Keyword.get(opts, :path, "")
    goth_server = Keyword.fetch!(opts, :goth_server)

    object_id = Util.object_id(scope)
    object_path = Util.build_object_path(path, object_id, filename)

    with {:ok, conn} <- auth(goth_server),
         {:ok, %{status: 200, body: data}} <-
           Objects.storage_objects_get(conn, bucket, object_path, [alt: "media"], []) do
      {:ok, data}
    else
      {:error, %Tesla.Env{body: body}} ->
        {:error, Jason.decode!(body)}
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
  def url(filename, scope, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    path = Keyword.get(opts, :path, "")
    goth_server = Keyword.fetch!(opts, :goth_server)
    service_account = Keyword.fetch!(opts, :service_account)

    object_id = Util.object_id(scope)
    object_path = Util.build_object_path(path, object_id, filename)

    case Goth.fetch(goth_server) do
      {:ok, %{token: access_token}} ->
        oauth_config = %GcsSignedUrl.SignBlob.OAuthConfig{
          service_account: service_account,
          access_token: access_token
        }

        GcsSignedUrl.generate_v4(
          oauth_config,
          bucket,
          object_path,
          Keyword.get(opts, :gcs_signed_url, expires: 60)
        )
        |> case do
          {:ok, signed_url} ->
            {:ok, %Buckets.SignedURL{path: object_path, filename: filename, url: signed_url}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, %Tesla.Env{body: body}} ->
        {:error, Jason.decode!(body)}
    end
  end

  defp auth(goth_server) do
    with {:ok, token} <- Goth.fetch(goth_server) do
      {:ok, GoogleApi.Storage.V1.Connection.new(token.token)}
    end
  end
end
