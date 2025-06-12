defmodule Buckets.Adapters.S3Test do
  use ExUnit.Case

  alias Buckets.Adapters.S3

  import Buckets.Setup
  import Buckets.UploadFixtures

  @s3_opts Application.compile_env!(:buckets, TestCloud)[:locations][:amazon]

  setup :setup_scope

  @tag :live
  @tag :live_s3

  test "s3 put", context do
    %{data: {:file, path}} = object = pdf_object()

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert File.exists?(path)
    assert {:ok, %{}} = S3.put(object, remote_path, @s3_opts)

    assert "simple.pdf" = object.filename
    assert "application/pdf" = object.metadata.content_type
  end

  @tag :live
  @tag :live_s3

  test "s3 get", context do
    setup_bucket(context, @s3_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, data} = S3.get(remote_path, @s3_opts)
    assert is_binary(data)
  end

  @tag :live
  @tag :live_s3

  test "s3 url", context do
    setup_bucket(context, @s3_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    expected_url =
      "https://ex-buckets-test.s3.amazonaws.com/test/objects/#{context.scope}/simple.pdf?"

    assert {:ok, data} = S3.url(remote_path, @s3_opts)
    assert data.url =~ expected_url
  end

  @tag :live
  @tag :live_s3

  test "delete", context do
    setup_bucket(context, @s3_opts)

    remote_path = "test/objects/#{context.scope}/simple.pdf"

    assert {:ok, _response} = S3.delete(remote_path, @s3_opts)
    assert {:error, :not_found} = S3.get(remote_path, @s3_opts)
  end
end
