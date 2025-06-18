defmodule Buckets.Adapters.VolumeTest do
  use ExUnit.Case

  alias Buckets.Adapters.Volume

  import Buckets.Setup
  import Buckets.UploadFixtures

  @volume_opts TestCloud.Volume.config()

  setup :setup_scope

  test "put", context do
    %{data: {:file, path}} = object = pdf_object()

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert File.exists?(path)
    assert {:ok, %{}} = Volume.put(object, remote_path, @volume_opts)

    assert "simple.pdf" = object.filename
    assert "application/pdf" = object.metadata.content_type
  end

  test "get", context do
    setup_bucket(context, @volume_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, data} = Volume.get(remote_path, @volume_opts)
    assert is_binary(data)
  end

  test "url", context do
    setup_bucket(context, @volume_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    expected_url =
      "http://localhost:4000/__buckets__/" <>
        "#{URI.encode(@volume_opts[:bucket], &URI.char_unreserved?/1)}" <>
        "/test/objects/#{context.scope}/simple.pdf"

    assert {:ok, %Buckets.SignedURL{url: ^expected_url}} = Volume.url(remote_path, @volume_opts)
  end

  test "delete", context do
    setup_bucket(context, @volume_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"
    bucket_path = Path.join(@volume_opts[:bucket], remote_path)

    assert File.exists?(bucket_path)

    Buckets.delete(remote_path, @volume_opts)

    refute File.exists?(bucket_path)
  end

  describe "validate_config/1" do
    test "accepts valid config" do
      config = [
        adapter: Volume,
        bucket: "/tmp/test-bucket"
      ]

      assert {:ok, result} = Volume.validate_config(config)
      assert Enum.sort(result) == Enum.sort(config)
    end

    test "accepts valid config with optional fields" do
      config = [
        adapter: Volume,
        bucket: "/tmp/test-bucket",
        endpoint: MyEndpoint,
        base_url: "http://localhost:4000",
        path: "/custom/path"
      ]

      assert {:ok, result} = Volume.validate_config(config)
      assert Enum.sort(result) == Enum.sort(config)
    end

    test "rejects config missing required fields" do
      config = [adapter: Volume]

      assert {:error, _} = Volume.validate_config(config)
    end

    test "rejects config with unknown fields" do
      config = [
        adapter: Volume,
        bucket: "/tmp/test-bucket",
        unknown_field: "value"
      ]

      assert {:error, _} = Volume.validate_config(config)
    end
  end
end
