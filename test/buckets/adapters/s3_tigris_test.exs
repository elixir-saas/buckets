defmodule Buckets.Adapters.S3TigrisTest do
  use ExUnit.Case

  alias Buckets.Adapters.S3

  import Buckets.Setup
  import Buckets.UploadFixtures

  @tigris_opts TestCloud.Tigris.config()

  setup :setup_scope

  @tag :live
  @tag :live_tigris

  test "tigris put", context do
    %{data: {:file, path}} = object = pdf_object()

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert File.exists?(path)
    assert {:ok, %{}} = S3.put(object, remote_path, @tigris_opts)

    assert "simple.pdf" = object.filename
    assert "application/pdf" = object.metadata.content_type
  end

  @tag :live
  @tag :live_tigris

  test "tigris get", context do
    setup_bucket(context, @tigris_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, data} = S3.get(remote_path, @tigris_opts)
    assert is_binary(data)
  end

  @tag :live
  @tag :live_tigris

  test "tigris url", context do
    setup_bucket(context, @tigris_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    expected_url_start =
      "https://fly.storage.tigris.dev/aged-feather-1704/test/objects/#{context.scope}/simple.pdf?"

    assert {:ok, data} = S3.url(remote_path, @tigris_opts)
    assert String.starts_with?(data.url, expected_url_start)
  end

  @tag :live
  @tag :live_tigris

  test "tigris delete", context do
    setup_bucket(context, @tigris_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, _response} = S3.delete(remote_path, @tigris_opts)
    assert {:error, :not_found} = S3.get(remote_path, @tigris_opts)
  end

  describe "validate_config/1 with tigris provider" do
    test "accepts valid tigris config" do
      config = [
        adapter: S3,
        provider: :tigris,
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret"
      ]

      assert {:ok, result} = S3.validate_config(config)
      # Check that tigris endpoint is added
      result_map = Map.new(result)
      assert result_map[:endpoint_url] == "https://fly.storage.tigris.dev"
      # Check that all input keys are present
      config_map = Map.new(config)
      assert Map.take(result_map, Map.keys(config_map)) == config_map
    end

    test "accepts tigris config with custom region" do
      config = [
        adapter: S3,
        provider: :tigris,
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret",
        region: "auto"
      ]

      assert {:ok, result} = S3.validate_config(config)
      result_map = Map.new(result)
      assert result_map[:endpoint_url] == "https://fly.storage.tigris.dev"
      assert result_map[:region] == "auto"
    end
  end
end
