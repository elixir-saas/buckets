defmodule Buckets.Strategy.VolumeTest do
  use ExUnit.Case

  alias Buckets.Strategy.Volume

  import Buckets.Setup
  import Buckets.UploadFixtures

  @volume_opts Application.compile_env!(:buckets, :volume_opts)

  setup :setup_scope

  test "put", context do
    upload = pdf_upload()

    assert File.exists?(upload.path)
    assert {:ok, object} = Volume.put(upload, context.scope, @volume_opts)

    assert "simple.pdf" = object.filename
    assert "application/pdf" = object.content_type
    assert object.object_path == "test/objects/#{context.scope}/simple.pdf"
    assert object.object_url =~ "file://"
    assert object.object_url =~ "test/objects/#{context.scope}/simple.pdf"
  end

  test "get", context do
    setup_bucket(context, @volume_opts)

    assert {:ok, data} = Volume.get("simple.pdf", context.scope, @volume_opts)
    assert is_binary(data)
  end

  test "url", context do
    setup_bucket(context, @volume_opts)

    expected_url =
      "http://localhost:4000/__buckets__/volume" <>
        "?path=test%2Fobjects%2F#{context.scope}%2Fsimple.pdf" <>
        "&bucket=%2Fvar%2Ffolders%2Fd5%2Ff89z8ycn6vz_vlv1lbjzp9x00000gn%2FT%2F"

    assert {:ok, %Buckets.SignedURL{url: ^expected_url}} =
             Volume.url("simple.pdf", context.scope, @volume_opts)
  end

  test "delete", context do
    %{object: object} = setup_bucket(context, @volume_opts)

    "file://" <> file_path = object.object_url

    assert File.exists?(file_path)

    Buckets.delete("simple.pdf", context.scope, @volume_opts)

    refute File.exists?(file_path)
  end
end
