defmodule Buckets.Strategy.GCS.AuthTest do
  use ExUnit.Case, async: true

  alias Buckets.Strategy.GCS.Auth

  describe "validate_credentials/1" do
    test "validates required fields are present" do
      credentials = %{
        "client_email" => "test@example.com",
        "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----"
      }

      assert {:ok, ^credentials} = Auth.validate_credentials(credentials)
    end

    test "returns error for missing client_email" do
      credentials = %{
        "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----"
      }

      assert {:error, {:missing_credentials, ["client_email"]}} =
               Auth.validate_credentials(credentials)
    end

    test "returns error for missing private_key" do
      credentials = %{
        "client_email" => "test@example.com"
      }

      assert {:error, {:missing_credentials, ["private_key"]}} =
               Auth.validate_credentials(credentials)
    end

    test "returns error for multiple missing fields" do
      credentials = %{}

      assert {:error, {:missing_credentials, fields}} = Auth.validate_credentials(credentials)
      assert "client_email" in fields
      assert "private_key" in fields
    end
  end

  describe "load_credentials/1" do
    test "loads valid JSON credentials file" do
      credentials = %{
        "client_email" => "test@example.com",
        "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----"
      }

      json_content = Jason.encode!(credentials)

      # Create a temporary file
      path = System.tmp_dir!() |> Path.join("test_credentials.json")
      File.write!(path, json_content)

      try do
        assert {:ok, ^credentials} = Auth.load_credentials(path)
      after
        File.rm(path)
      end
    end

    test "returns error for non-existent file" do
      assert {:error, {:file_read_error, :enoent}} =
               Auth.load_credentials("/non/existent/path.json")
    end

    test "returns error for invalid JSON" do
      path = System.tmp_dir!() |> Path.join("invalid.json")
      File.write!(path, "invalid json")

      try do
        assert {:error, {:json_decode_error, _}} = Auth.load_credentials(path)
      after
        File.rm(path)
      end
    end
  end

  describe "generate_jwt/1" do
    test "returns error for invalid private key" do
      credentials = %{
        "client_email" => "test@example.com",
        "private_key" => "invalid-key"
      }

      assert {:error, {:jwt_generation_failed, _}} = Auth.generate_jwt(credentials)
    end

    test "returns error for missing fields" do
      credentials = %{
        "client_email" => "test@example.com"
        # missing private_key
      }

      # Should return an error tuple due to missing private_key
      assert {:error, {:jwt_generation_failed, _}} = Auth.generate_jwt(credentials)
    end
  end
end
