defmodule Buckets.Strategy.GCS.Signature do
  @moduledoc """
  Google Cloud Storage V4 signed URL generation.

  Implements the V4 signing process for creating signed URLs that allow
  temporary access to GCS objects without requiring authentication.
  """

  @doc """
  Generates a V4 signed URL for Google Cloud Storage.

  ## Options

    * `:verb` - HTTP method (default: "GET")
    * `:expires` - Expiration time in seconds from now (default: 3600)
    * `:headers` - Additional headers to include in the signature

  ## Examples

      iex> credentials = %{"client_email" => "test@example.com", "private_key" => "..."}
      iex> Buckets.Strategy.GCS.Signature.generate_v4(credentials, "my-bucket", "path/to/object.jpg")
      {:ok, "https://storage.googleapis.com/my-bucket/path%2Fto%2Fobject.jpg?X-Goog-Algorithm=..."}
  """
  @spec generate_v4(map(), String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_v4(credentials, bucket, object_path, opts \\ []) do
    verb = Keyword.get(opts, :verb, "GET")
    expires = Keyword.get(opts, :expires, 3600)
    headers = Keyword.get(opts, :headers, [])

    client_email = Map.fetch!(credentials, "client_email")
    private_key = Map.fetch!(credentials, "private_key")

    datetime = DateTime.utc_now()
    _expiration_datetime = DateTime.add(datetime, expires, :second)

    # Format timestamps
    request_timestamp = format_timestamp(datetime)

    # Create credential scope
    date_stamp = String.slice(request_timestamp, 0, 8)
    credential_scope = "#{date_stamp}/auto/storage/goog4_request"
    credential = "#{client_email}/#{credential_scope}"

    # Prepare query parameters
    query_params = %{
      "X-Goog-Algorithm" => "GOOG4-RSA-SHA256",
      "X-Goog-Credential" => credential,
      "X-Goog-Date" => request_timestamp,
      "X-Goog-Expires" => to_string(expires),
      "X-Goog-SignedHeaders" => build_signed_headers_string(headers)
    }

    # Build canonical request
    canonical_request =
      build_canonical_request(
        verb,
        bucket,
        object_path,
        query_params,
        headers
      )

    # Build string to sign
    string_to_sign =
      build_string_to_sign(
        request_timestamp,
        credential_scope,
        canonical_request
      )

    # Generate signature
    case sign_string(string_to_sign, private_key) do
      {:ok, signature} ->
        final_query_params = Map.put(query_params, "X-Goog-Signature", signature)
        url = build_signed_url(bucket, object_path, final_query_params)
        {:ok, url}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error -> {:error, {:signed_url_generation_failed, error}}
  end

  ## Private

  defp format_timestamp(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
    |> String.replace("Z", "")
  end

  defp build_signed_headers_string(headers) do
    headers
    |> Enum.map(fn {key, _value} -> String.downcase(to_string(key)) end)
    |> Enum.sort()
    |> Enum.join(";")
  end

  defp build_canonical_request(verb, _bucket, object_path, query_params, headers) do
    # Encode object path
    canonical_uri = "/" <> URI.encode(object_path, &uri_encode_char/1)

    # Build canonical query string
    canonical_query_string =
      query_params
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map(fn {key, value} ->
        "#{URI.encode(key, &uri_encode_char/1)}=#{URI.encode(value, &uri_encode_char/1)}"
      end)
      |> Enum.join("&")

    # Build canonical headers
    canonical_headers =
      headers
      |> Enum.map(fn {key, value} ->
        "#{String.downcase(to_string(key))}:#{String.trim(to_string(value))}\n"
      end)
      |> Enum.sort()
      |> Enum.join("")

    # Build signed headers
    signed_headers = build_signed_headers_string(headers)

    # Hash empty payload for most requests
    payload_hash = hash_sha256("")

    [
      verb,
      canonical_uri,
      canonical_query_string,
      canonical_headers,
      signed_headers,
      payload_hash
    ]
    |> Enum.join("\n")
  end

  defp build_string_to_sign(request_timestamp, credential_scope, canonical_request) do
    canonical_request_hash = hash_sha256(canonical_request)

    [
      "GOOG4-RSA-SHA256",
      request_timestamp,
      credential_scope,
      canonical_request_hash
    ]
    |> Enum.join("\n")
  end

  defp sign_string(string_to_sign, private_key) do
    try do
      # Parse the private key PEM
      [entry] = :public_key.pem_decode(private_key)
      private_key_decoded = :public_key.pem_entry_decode(entry)

      # Sign the string using RSA-SHA256
      signature =
        string_to_sign
        |> :public_key.sign(:sha256, private_key_decoded)
        |> Base.encode16(case: :lower)

      {:ok, signature}
    rescue
      error -> {:error, {:signing_failed, error}}
    end
  end

  defp build_signed_url(bucket, object_path, query_params) do
    encoded_object_path = URI.encode(object_path, &uri_encode_char/1)
    query_string = URI.encode_query(query_params)

    "https://storage.googleapis.com/#{bucket}/#{encoded_object_path}?#{query_string}"
  end

  defp hash_sha256(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end

  # URI encoding function that matches Google's requirements
  defp uri_encode_char(c) when c in ?A..?Z, do: true
  defp uri_encode_char(c) when c in ?a..?z, do: true
  defp uri_encode_char(c) when c in ?0..?9, do: true
  defp uri_encode_char(c) when c in [?-, ?_, ?., ?~], do: true
  defp uri_encode_char(_), do: false
end
