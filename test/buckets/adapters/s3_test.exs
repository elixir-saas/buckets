defmodule Buckets.Adapters.S3Test do
  use ExUnit.Case

  alias Buckets.Adapters.S3

  import Buckets.Setup
  import Buckets.UploadFixtures

  @s3_opts TestCloud.S3.config()

  setup :setup_scope

  @tag :live
  @tag :live_s3

  test "s3 put", context do
    %{data: {:file, path}} = object = pdf_object()

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert File.exists?(path)
    assert {:ok, %{}} = S3.put(object, remote_path, @s3_opts)

    assert "simple.pdf" = object.filename
    assert "application/pdf" = object.metadata.content_type
  end

  @tag :live
  @tag :live_s3

  test "s3 get", context do
    setup_bucket(context, @s3_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, data} = S3.get(remote_path, @s3_opts)
    assert is_binary(data)
  end

  @tag :live
  @tag :live_s3

  test "s3 url", context do
    setup_bucket(context, @s3_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    expected_url =
      "https://ex-buckets-test.s3.amazonaws.com/test/objects/#{context.scope}/simple.pdf?"

    assert {:ok, data} = S3.url(remote_path, @s3_opts)
    assert data.url =~ expected_url
  end

  @tag :live
  @tag :live_s3

  test "delete", context do
    setup_bucket(context, @s3_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, _response} = S3.delete(remote_path, @s3_opts)
    assert {:error, :not_found} = S3.get(remote_path, @s3_opts)
  end

  @tag :live
  @tag :live_s3

  test "upload to signed url", context do
    %{data: {:file, path}} = pdf_object()
    remote_path = "test/objects/#{context.scope}/signed_upload.pdf"

    # Read the file content
    file_content = File.read!(path)

    # Generate a signed URL for upload
    opts = Keyword.put(@s3_opts, :for_upload, true)

    assert {:ok, %Buckets.SignedURL{url: signed_url}} = S3.url(remote_path, opts)

    # Upload using the signed URL
    case Req.put(signed_url, body: file_content) do
      {:ok, %{status: status}} when status in [200, 201] ->
        # Success - verify the file was uploaded
        assert {:ok, data} = S3.get(remote_path, @s3_opts)
        assert data == file_content

        # Clean up
        assert {:ok, _} = S3.delete(remote_path, @s3_opts)

      {:ok, %{status: status, body: body}} ->
        flunk("Upload failed with status #{status}: #{inspect(body)}")

      {:error, reason} ->
        flunk("Upload request failed: #{inspect(reason)}")
    end
  end

  describe "validate_config/1" do
    test "accepts valid config" do
      config = [
        adapter: S3,
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret"
      ]

      assert {:ok, result} = S3.validate_config(config)
      # Check that all input keys are present in result
      config_map = Map.new(config)
      result_map = Map.new(result)
      assert Map.take(result_map, Map.keys(config_map)) == config_map
    end

    test "accepts valid config with optional fields" do
      config = [
        adapter: S3,
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret",
        provider: :aws,
        region: "us-east-1",
        path: "/custom/path"
      ]

      assert {:ok, result} = S3.validate_config(config)
      # Check that all input keys are present in result
      config_map = Map.new(config)
      result_map = Map.new(result)
      assert Map.take(result_map, Map.keys(config_map)) == config_map
    end

    test "rejects config missing required fields" do
      config = [
        adapter: S3,
        bucket: "test-bucket"
      ]

      assert {:error, _} = S3.validate_config(config)
    end

    test "rejects config with unknown fields" do
      config = [
        adapter: S3,
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret",
        unknown_field: "value"
      ]

      assert {:error, _} = S3.validate_config(config)
    end
  end
end
