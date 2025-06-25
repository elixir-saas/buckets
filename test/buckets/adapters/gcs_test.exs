defmodule Buckets.Adapters.GCSTest do
  use ExUnit.Case

  alias Buckets.Adapters.GCS

  import Buckets.Setup
  import Buckets.UploadFixtures

  @gcs_opts TestCloud.GCS.config()

  setup :setup_scope

  @tag :live
  @tag :live_gcs

  test "gcs put", context do
    %{data: {:file, path}} = object = pdf_object()

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert File.exists?(path)
    assert {:ok, %{}} = GCS.put(object, remote_path, @gcs_opts)

    assert "simple.pdf" = object.filename
    assert "application/pdf" = object.metadata.content_type
  end

  @tag :live
  @tag :live_gcs

  test "gcs get", context do
    setup_bucket(context, @gcs_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, data} = GCS.get(remote_path, @gcs_opts)
    assert is_binary(data)
  end

  @tag :live
  @tag :live_gcs

  test "gcs url", context do
    setup_bucket(context, @gcs_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    expected_url_start =
      "https://storage.googleapis.com/#{@gcs_opts[:bucket]}/test%2Fobjects%2F#{context.scope}%2Fsimple.pdf?"

    assert {:ok, data} = GCS.url(remote_path, @gcs_opts)
    assert String.starts_with?(data.url, expected_url_start)
  end

  @tag :live
  @tag :live_gcs

  test "delete", context do
    setup_bucket(context, @gcs_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, _response} = GCS.delete(remote_path, @gcs_opts)
    assert {:error, :not_found} = GCS.get(remote_path, @gcs_opts)
  end

  @tag :live
  @tag :live_gcs

  test "upload to signed url", context do
    %{data: {:file, path}} = pdf_object()
    remote_path = "test/objects/#{context.scope}/signed_upload.pdf"

    # Read the file content
    file_content = File.read!(path)

    # Generate a signed URL for upload
    # The signature code now automatically includes the required host header
    opts = Keyword.put(@gcs_opts, :for_upload, true)

    assert {:ok, %Buckets.SignedURL{url: signed_url}} = GCS.url(remote_path, opts)

    # Upload using the signed URL
    # Try without explicitly setting the host header since Req should handle it
    case Req.put(signed_url, body: file_content) do
      {:ok, %{status: status}} when status in [200, 201] ->
        # Success - verify the file was uploaded
        assert {:ok, data} = GCS.get(remote_path, @gcs_opts)
        assert data == file_content

        # Clean up
        assert {:ok, _} = GCS.delete(remote_path, @gcs_opts)

      {:ok, %{status: status, body: body}} ->
        flunk("Upload failed with status #{status}: #{inspect(body)}")

      {:error, reason} ->
        flunk("Upload request failed: #{inspect(reason)}")
    end
  end

  describe "validate_config/1" do
    test "accepts valid config with service_account_path" do
      config = [
        adapter: GCS,
        bucket: "test-bucket",
        service_account_path: "/path/to/service-account.json"
      ]

      assert {:ok, result} = GCS.validate_config(config)
      # Check that all input keys are present in result
      config_map = Map.new(config)
      result_map = Map.new(result)
      assert Map.take(result_map, Map.keys(config_map)) == config_map
    end

    test "accepts valid config with service_account_credentials" do
      config = [
        adapter: GCS,
        bucket: "test-bucket",
        service_account_credentials: %{"type" => "service_account"}
      ]

      assert {:ok, result} = GCS.validate_config(config)
      # Check that all input keys are present in result
      config_map = Map.new(config)
      result_map = Map.new(result)
      assert Map.take(result_map, Map.keys(config_map)) == config_map
    end

    test "accepts valid config with optional path" do
      config = [
        adapter: GCS,
        bucket: "test-bucket",
        service_account_path: "/path/to/service-account.json",
        path: "/custom/path"
      ]

      assert {:ok, result} = GCS.validate_config(config)
      # Check that all input keys are present in result
      config_map = Map.new(config)
      result_map = Map.new(result)
      assert Map.take(result_map, Map.keys(config_map)) == config_map
    end

    test "rejects config missing required fields" do
      config = [adapter: GCS]

      assert {:error, _} = GCS.validate_config(config)
    end

    test "rejects config without service account info" do
      config = [
        adapter: GCS,
        bucket: "test-bucket"
      ]

      assert {:error, [:service_account_path, :service_account_credentials]} =
               GCS.validate_config(config)
    end

    test "rejects config with unknown fields" do
      config = [
        adapter: GCS,
        bucket: "test-bucket",
        service_account_path: "/path/to/service-account.json",
        unknown_field: "value"
      ]

      assert {:error, _} = GCS.validate_config(config)
    end
  end
end
