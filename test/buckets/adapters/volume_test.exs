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
        "#{Base.url_encode64(@volume_opts[:bucket], padding: false)}" <>
        "/test/objects/#{context.scope}/simple.pdf"

    assert {:ok, %Buckets.SignedURL{url: ^expected_url}} = Volume.url(remote_path, @volume_opts)
  end

  test "copy", context do
    setup_bucket(context, @volume_opts)

    source_path = "test/objects/#{context.scope}/simple.pdf"
    dest_path = "test/objects/#{context.scope}/copied.pdf"

    assert {:ok, %{}} = Volume.copy(source_path, dest_path, @volume_opts)

    source_full = Path.join(@volume_opts[:bucket], source_path)
    dest_full = Path.join(@volume_opts[:bucket], dest_path)

    assert File.exists?(source_full)
    assert File.exists?(dest_full)
    assert File.read!(source_full) == File.read!(dest_full)
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
