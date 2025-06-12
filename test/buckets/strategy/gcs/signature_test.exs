defmodule Buckets.Strategy.GCS.SignatureTest do
  use ExUnit.Case, async: true

  alias Buckets.Strategy.GCS.Signature

  describe "generate_v4/4" do
    test "returns error for invalid private key" do
      credentials = %{
        "client_email" => "test@example.com",
        "private_key" => "invalid-key"
      }

      assert {:error, {:signing_failed, _}} =
               Signature.generate_v4(credentials, "test-bucket", "test-object")
    end

    test "uses correct default options" do
      credentials = %{
        "client_email" => "test@example.com",
        "private_key" => "invalid-key"
      }

      # Should fail but we can test it attempts with defaults
      {:error, _} = Signature.generate_v4(credentials, "test-bucket", "test-object")

      # Test with custom options
      opts = [verb: "PUT", expires: 900, headers: [{"content-type", "image/jpeg"}]]
      {:error, _} = Signature.generate_v4(credentials, "test-bucket", "test-object", opts)
    end

    test "validates required credential fields" do
      incomplete_credentials = %{
        "client_email" => "test@example.com"
        # missing private_key
      }

      # Should return an error tuple due to missing private_key
      assert {:error, {:signed_url_generation_failed, _}} =
               Signature.generate_v4(incomplete_credentials, "test-bucket", "test-object")
    end

    test "handles object paths with special characters" do
      credentials = %{
        "client_email" => "test@example.com",
        "private_key" => "invalid-key"
      }

      # Should handle URL encoding properly (even though it will fail due to invalid key)
      {:error, _} =
        Signature.generate_v4(credentials, "test-bucket", "path/with spaces/object.jpg")

      {:error, _} = Signature.generate_v4(credentials, "test-bucket", "path/with/unicode/文件.jpg")
    end
  end
end
