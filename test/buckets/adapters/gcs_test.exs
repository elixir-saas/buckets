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
