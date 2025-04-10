defmodule Buckets.CloudTest do
  use ExUnit.Case

  describe "insert/2" do
    test "inserts path to google" do
      assert {:ok, %{stored?: true} = object} =
               TestCloud.insert("priv/simple.pdf", location: :google_cloud)

      # IO.inspect(object)

      assert object.uuid != nil
      assert object.filename == "simple.pdf"
      assert object.data == {:file, "priv/simple.pdf"}
      assert object.metadata == %{content_type: "application/pdf", content_size: 3028}
      assert object.location.path =~ "test/objects/"

      object = %{object | data: nil}

      {:ok, object} = TestCloud.load(object, to: {:tmp, "_scope"})
      IO.inspect(object)

      {:ok, object} = TestCloud.load(object, force: true)
      IO.inspect(object)
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
      object = Buckets.ObjectV2.from_file("priv/simple.pdf")

      assert {:ok, %{stored?: true} = object} = TestCloud.insert(object)

      assert object.uuid != nil
      assert object.filename == "simple.pdf"
      assert object.data == {:file, "priv/simple.pdf"}
      assert object.metadata == %{content_type: "application/pdf", content_size: 3028}
      assert object.location.path =~ "test/objects/"
    end
  end
end
