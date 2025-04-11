defmodule Buckets.CloudTest do
  use ExUnit.Case

  describe "insert/2" do
    @tag :live
    @tag :live_gcs

    test "inserts path to google" do
      assert {:ok, %{stored?: true} = object} =
               TestCloud.insert("priv/simple.pdf", location: :google_cloud)

      assert object.uuid != nil
      assert object.filename == "simple.pdf"
      assert object.data == {:file, "priv/simple.pdf"}
      assert object.metadata == %{content_type: "application/pdf", content_size: 3028}
      assert object.location.path =~ "test/objects/"

      object = %{object | data: nil}

      assert {:ok, object} = TestCloud.load(object, to: {:tmp, "_scope"})
      assert {:file, _path} = object.data

      assert {:ok, object} = TestCloud.load(object, force: true)
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

    test "inserts path to location" do
      assert {:ok, %{stored?: true} = object} =
               TestCloud.insert("priv/simple.pdf", location: :other_local)

      assert object.uuid != nil
      assert object.filename == "simple.pdf"
      assert object.data == {:file, "priv/simple.pdf"}
      assert object.metadata == %{content_type: "application/pdf", content_size: 3028}
      assert object.location.path =~ "test_other/objects/"
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
