defmodule Buckets.Strategy.VolumeTest do
  use ExUnit.Case

  alias Buckets.Strategy.Volume

  import Buckets.Setup
  import Buckets.UploadFixtures

  @volume_opts Application.compile_env!(:buckets, :volume_opts)

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
      "http://localhost:4000/__buckets__/volume" <>
        "?path=test%2Fobjects%2F#{context.scope}%2Fsimple.pdf" <>
        "&bucket=%2Fvar%2Ffolders%2Fd5%2Ff89z8ycn6vz_vlv1lbjzp9x00000gn%2FT%2F"

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
end
