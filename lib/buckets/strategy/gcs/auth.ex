defmodule Buckets.Strategy.GCS.Auth do
  @moduledoc """
  Google Cloud Storage authentication using service account credentials.

  Handles JWT token generation and OAuth2 token exchange without external dependencies.
  """

  require Logger

  @token_uri "https://oauth2.googleapis.com/token"
  @scope "https://www.googleapis.com/auth/cloud-platform"

  @doc """
  Gets an access token for GCS API access.

  ## Examples

      iex> credentials = %{
      ...>   "client_email" => "test@example.com",
      ...>   "private_key" => "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----"
      ...> }
      iex> Buckets.GCS.Auth.get_access_token(credentials)
      {:ok, "ya29.c.Ko8..."}
  """
  @spec get_access_token(map()) :: {:ok, String.t()} | {:error, term()}
  def get_access_token(credentials) do
    with {:ok, jwt} <- generate_jwt(credentials),
         {:ok, token} <- exchange_jwt_for_token(jwt) do
      {:ok, token}
    end
  end

  @doc """
  Generates a JWT token for Google service account authentication.
  """
  @spec generate_jwt(map()) :: {:ok, String.t()} | {:error, term()}
  def generate_jwt(credentials) do
    client_email = Map.fetch!(credentials, "client_email")
    private_key = Map.fetch!(credentials, "private_key")

    now = System.system_time(:second)
    # 1 hour expiration
    exp = now + 3600

    payload = %{
      "iss" => client_email,
      "scope" => @scope,
      "aud" => @token_uri,
      "iat" => now,
      "exp" => exp
    }

    jwk = JOSE.JWK.from_pem(private_key)
    jwt = JOSE.JWT.sign(jwk, %{"alg" => "RS256"}, payload)

    {%{alg: :jose_jws_alg_rsa_pkcs1_v1_5}, jwt_string} = JOSE.JWS.compact(jwt)

    {:ok, jwt_string}
  rescue
    error -> {:error, {:jwt_generation_failed, error}}
  end

  @doc """
  Exchanges a JWT token for an access token via Google's OAuth2 endpoint.
  """
  @spec exchange_jwt_for_token(String.t()) :: {:ok, String.t()} | {:error, term()}
  def exchange_jwt_for_token(jwt) do
    body =
      URI.encode_query(%{
        "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion" => jwt
      })

    headers = [
      {"content-type", "application/x-www-form-urlencoded"}
    ]

    case Req.post(@token_uri, body: body, headers: headers) do
      {:ok, %{status: 200, body: response_body}} ->
        case response_body do
          %{"access_token" => token} ->
            {:ok, token}

          response ->
            {:error, {:invalid_token_response, response}}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Get service account credentials from a location config.
  """
  @spec get_credentials(Keyword.t()) :: {:ok, map()} | {:error, term()}
  def get_credentials(config) do
    cond do
      path = config[:service_account_path] ->
        load_credentials(path)

      credentials_json = config[:service_account_credentials] ->
        parse_credentials(credentials_json)

      true ->
        {:error, :missing_credentials}
    end
  end

  @doc """
  Loads service account credentials from a file path.
  """
  @spec load_credentials(String.t()) :: {:ok, map()} | {:error, term()}
  def load_credentials(path) do
    case File.read(path) do
      {:ok, credentials_json} ->
        parse_credentials(credentials_json)

      {:error, reason} ->
        {:error, {:file_read_error, reason}}
    end
  end

  @doc """
  Parse service account credentials from a JSON string.
  """
  @spec parse_credentials(String.t()) :: {:ok, map()} | {:error, term()}
  def parse_credentials(credentials_json) do
    with {:ok, credentials} <- Jason.decode(credentials_json),
         {:ok, credentials} <- validate_credentials(credentials) do
      {:ok, credentials}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, {:json_decode_error, error}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates that service account credentials contain required fields.
  """
  @spec validate_credentials(map()) :: :ok | {:error, term()}
  def validate_credentials(credentials) do
    required_fields = ["client_email", "private_key"]

    case Enum.reject(required_fields, &Map.has_key?(credentials, &1)) do
      [] -> {:ok, credentials}
      fields -> {:error, {:missing_credentials, fields}}
    end
  end
end
