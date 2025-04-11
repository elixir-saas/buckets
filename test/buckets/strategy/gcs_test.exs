defmodule Buckets.Strategy.GCSTest do
  use ExUnit.Case

  alias Buckets.Strategy.GCS

  import Buckets.Setup
  import Buckets.UploadFixtures

  @gcs_opts Application.compile_env!(:buckets, :gcs_opts)

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

    expected_url =
      "https://storage.googleapis.com/#{@gcs_opts[:bucket]}/test/objects/#{context.scope}/simple.pdf?"

    assert {:ok, data} = GCS.url(remote_path, @gcs_opts)
    assert data.url =~ expected_url
  end

  @tag :live
  @tag :live_gcs

  test "delete", context do
    setup_bucket(context, @gcs_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, _response} = GCS.delete(remote_path, @gcs_opts)
    assert {:error, "No such object:" <> _} = GCS.get(remote_path, @gcs_opts)
  end
end
