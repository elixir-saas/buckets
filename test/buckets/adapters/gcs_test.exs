defmodule Buckets.Adapters.GCSTest do
  use ExUnit.Case

  alias Buckets.Adapters.GCS

  import Buckets.Setup
  import Buckets.UploadFixtures

  @gcs_opts Application.compile_env!(:buckets, TestCloud)[:locations][:google]
            |> Keyword.put(:__location_key__, :google)

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

    expected_url_start =
      "https://storage.googleapis.com/#{@gcs_opts[:bucket]}/test%2Fobjects%2F#{context.scope}%2Fsimple.pdf?"

    assert {:ok, data} = GCS.url(remote_path, @gcs_opts)
    assert String.starts_with?(data.url, expected_url_start)
  end

  @tag :live
  @tag :live_gcs

  test "delete", context do
    setup_bucket(context, @gcs_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, _response} = GCS.delete(remote_path, @gcs_opts)
    assert {:error, :not_found} = GCS.get(remote_path, @gcs_opts)
  end
end
