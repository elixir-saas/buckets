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
end
