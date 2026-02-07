defmodule Buckets.CloudTest do
  use ExUnit.Case

  describe "insert/2" do
    @tag :live
    @tag :live_gcs

    test "inserts path to google" do
      assert {:ok, %{stored?: true} = object} =
               TestCloud.GCS.insert("priv/simple.pdf")

      assert object.uuid != nil
      assert object.filename == "simple.pdf"
      assert object.data == {:file, "priv/simple.pdf"}
      assert object.metadata == %{content_type: "application/pdf", content_size: 3028}
      assert object.location.path =~ "test/objects/"

      object = %{object | data: nil}

      assert {:ok, object} = TestCloud.GCS.load(object, to: {:tmp, "_scope"})
      assert {:file, _path} = object.data

      assert {:ok, object} = TestCloud.GCS.load(object, force: true)
      assert {:data, _data} = object.data
    end

    @tag :live
    @tag :live_aws

    test "inserts path to amazon" do
      assert {:ok, %{stored?: true} = object} =
               TestCloud.S3.insert("priv/simple.pdf")

      assert object.uuid != nil
      assert object.filename == "simple.pdf"
      assert object.data == {:file, "priv/simple.pdf"}
      assert object.metadata == %{content_type: "application/pdf", content_size: 3028}
      assert object.location.path =~ "test/objects/"

      object = %{object | data: nil}

      assert {:ok, object} = TestCloud.S3.load(object, to: {:tmp, "_scope"})
      assert {:file, _path} = object.data

      assert {:ok, object} = TestCloud.S3.load(object, force: true)
      assert {:data, _data} = object.data
    end

    test "inserts path" do
      assert {:ok, %{stored?: true} = object} = TestCloud.insert("priv/simple.pdf")

      assert object.uuid != nil
      assert object.filename == "simple.pdf"
      assert object.data == {:file, "priv/simple.pdf"}
      assert object.metadata == %{content_type: "application/pdf", content_size: 3028}
      assert object.location.path =~ "test/objects/"
    end

    test "inserts path with custom config" do
      custom_config = [
        adapter: Buckets.Adapters.Volume,
        bucket: System.tmp_dir!(),
        path: "test_other/objects"
      ]

      assert {:ok, %{stored?: true} = object} =
               TestCloud.with_config(custom_config, fn ->
                 TestCloud.insert("priv/simple.pdf")
               end)

      assert object.uuid != nil
      assert object.filename == "simple.pdf"
      assert object.data == {:file, "priv/simple.pdf"}
      assert object.metadata == %{content_type: "application/pdf", content_size: 3028}
      assert object.location.path =~ "test_other/objects/"
    end

    test "inserts and copies object" do
      assert {:ok, %{stored?: true} = object} = TestCloud.insert("priv/simple.pdf")

      dest_path = "test/objects/copied/simple_copy.pdf"
      assert {:ok, %{stored?: true} = copied} = TestCloud.copy(object, dest_path)

      assert copied.uuid != object.uuid
      assert copied.filename == "simple_copy.pdf"
      assert copied.data == nil
      assert copied.location.path == dest_path

      # Both objects should be readable
      assert {:ok, original_data} = TestCloud.read(object)
      assert {:ok, copied_data} = TestCloud.read(copied)
      assert original_data == copied_data
    end

    test "inserts object" do
      object = Buckets.Object.from_file("priv/simple.pdf")

      assert {:ok, %{stored?: true} = object} = TestCloud.insert(object)

      assert object.uuid != nil
      assert object.filename == "simple.pdf"
      assert object.data == {:file, "priv/simple.pdf"}
      assert object.metadata == %{content_type: "application/pdf", content_size: 3028}
      assert object.location.path =~ "test/objects/"
    end
  end
end
