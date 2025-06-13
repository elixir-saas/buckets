defmodule Buckets.Adapters.S3CloudflareR2Test do
  use ExUnit.Case

  alias Buckets.Adapters.S3

  import Buckets.Setup
  import Buckets.UploadFixtures

  @r2_opts TestCloud.config_for(:cloudflare_r2)

  setup :setup_scope

  @tag :live
  @tag :live_cloudflare_r2

  test "cloudflare r2 put", context do
    %{data: {:file, path}} = object = pdf_object()

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert File.exists?(path)
    assert {:ok, %{}} = S3.put(object, remote_path, @r2_opts)

    assert "simple.pdf" = object.filename
    assert "application/pdf" = object.metadata.content_type
  end

  @tag :live
  @tag :live_cloudflare_r2

  test "cloudflare r2 get", context do
    setup_bucket(context, @r2_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, data} = S3.get(remote_path, @r2_opts)
    assert is_binary(data)
  end

  @tag :live
  @tag :live_cloudflare_r2

  test "cloudflare r2 url", context do
    setup_bucket(context, @r2_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    expected_url_start =
      "https://261f9f435619b5b4c8fd3bd26cac7bff.r2.cloudflarestorage.com/ex-buckets-test/test/objects/#{context.scope}/simple.pdf?"

    assert {:ok, data} = S3.url(remote_path, @r2_opts)
    assert String.starts_with?(data.url, expected_url_start)
  end

  @tag :live
  @tag :live_cloudflare_r2

  test "cloudflare r2 delete", context do
    setup_bucket(context, @r2_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, _response} = S3.delete(remote_path, @r2_opts)
    assert {:error, :not_found} = S3.get(remote_path, @r2_opts)
  end

  describe "validate_config/1 with cloudflare provider" do
    test "accepts valid cloudflare config with endpoint_url" do
      config = [
        adapter: S3,
        provider: :cloudflare_r2,
        endpoint_url: "https://account-id.r2.cloudflarestorage.com",
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret"
      ]

      assert {:ok, result} = S3.validate_config(config)
      # Check that all input keys are present
      config_map = Map.new(config)
      result_map = Map.new(result)
      assert Map.take(result_map, Map.keys(config_map)) == config_map
      # Region should be "auto" (default)
      assert result_map[:region] == "auto"
    end

    test "accepts cloudflare config with custom region" do
      config = [
        adapter: S3,
        provider: :cloudflare_r2,
        endpoint_url: "https://account-id.r2.cloudflarestorage.com",
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret",
        region: "auto"
      ]

      assert {:ok, result} = S3.validate_config(config)
      result_map = Map.new(result)
      assert result_map[:region] == "auto"
      assert result_map[:endpoint_url] == "https://account-id.r2.cloudflarestorage.com"
    end

    test "rejects cloudflare config without endpoint_url" do
      config = [
        adapter: S3,
        provider: :cloudflare_r2,
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret"
      ]

      assert {:error, [:endpoint_url]} = S3.validate_config(config)
    end
  end
end
