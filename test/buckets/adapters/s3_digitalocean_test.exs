defmodule Buckets.Adapters.S3DigitalOceanTest do
  use ExUnit.Case

  alias Buckets.Adapters.S3

  import Buckets.Setup
  import Buckets.UploadFixtures

  @digitalocean_opts TestCloud.DigitalOcean.config()

  setup :setup_scope

  @tag :live
  @tag :live_digitalocean

  test "digitalocean put", context do
    %{data: {:file, path}} = object = pdf_object()

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert File.exists?(path)
    assert {:ok, %{}} = S3.put(object, remote_path, @digitalocean_opts)

    assert "simple.pdf" = object.filename
    assert "application/pdf" = object.metadata.content_type
  end

  @tag :live
  @tag :live_digitalocean

  test "digitalocean get", context do
    setup_bucket(context, @digitalocean_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, data} = S3.get(remote_path, @digitalocean_opts)
    assert is_binary(data)
  end

  @tag :live
  @tag :live_digitalocean

  test "digitalocean url", context do
    setup_bucket(context, @digitalocean_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    expected_url_start =
      "https://nyc3.digitaloceanspaces.com/ex-buckets-test/test/objects/#{context.scope}/simple.pdf?"

    assert {:ok, data} = S3.url(remote_path, @digitalocean_opts)
    assert String.starts_with?(data.url, expected_url_start)
  end

  @tag :live
  @tag :live_digitalocean

  test "digitalocean delete", context do
    setup_bucket(context, @digitalocean_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, _response} = S3.delete(remote_path, @digitalocean_opts)
    assert {:error, :not_found} = S3.get(remote_path, @digitalocean_opts)
  end

  describe "validate_config/1 with digitalocean provider" do
    test "accepts valid digitalocean config" do
      config = [
        adapter: S3,
        provider: :digitalocean,
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret"
      ]

      assert {:ok, result} = S3.validate_config(config)
      # Check that digitalocean endpoint is added, region will be "auto" (default)
      result_map = Map.new(result)
      assert result_map[:endpoint_url] == "https://nyc3.digitaloceanspaces.com"
      assert result_map[:region] == "auto"
      # Check that all input keys are present
      config_map = Map.new(config)
      assert Map.take(result_map, Map.keys(config_map)) == config_map
    end

    test "accepts digitalocean config with custom region" do
      config = [
        adapter: S3,
        provider: :digitalocean,
        bucket: "test-bucket",
        access_key_id: "test-key",
        secret_access_key: "test-secret",
        region: "sfo3"
      ]

      assert {:ok, result} = S3.validate_config(config)
      result_map = Map.new(result)
      # Custom region should override default
      assert result_map[:region] == "sfo3"
      assert result_map[:endpoint_url] == "https://nyc3.digitaloceanspaces.com"
    end
  end
end
