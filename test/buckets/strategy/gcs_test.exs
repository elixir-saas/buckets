defmodule Buckets.Strategy.GCSTest do
  use ExUnit.Case

  alias Buckets.Strategy.GCS

  import Buckets.Setup
  import Buckets.UploadFixtures

  @gcs_opts Application.compile_env!(:buckets, :gcs_opts)

  setup :setup_scope

  test "gcs put", context do
    upload = pdf_upload()

    assert File.exists?(upload.path)
    assert {:ok, object} = GCS.put(upload, context.scope, @gcs_opts)

    assert "simple.pdf" = object.filename
    assert "application/pdf" = object.content_type
    assert object.object_path == "test/objects/#{context.scope}/simple.pdf"
    assert object.object_url =~ "https://storage.googleapis.com/download/storage/v1/"
  end

  test "gcs get", context do
    setup_bucket(context, @gcs_opts)

    assert {:ok, data} = GCS.get("simple.pdf", context.scope, @gcs_opts)
    assert is_binary(data)
  end

  test "gcs url", context do
    setup_bucket(context, @gcs_opts)

    expected_url =
      "https://storage.googleapis.com/#{@gcs_opts[:bucket]}/test/objects/#{context.scope}/simple.pdf?"

    assert {:ok, data} = GCS.url("simple.pdf", context.scope, @gcs_opts)
    assert data =~ expected_url
  end
end
