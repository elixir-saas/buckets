defmodule Buckets.LocationTest do
  use ExUnit.Case, async: true

  alias Buckets.Location

  describe "inspect/1" do
    test "redacts config field" do
      config = [adapter: Buckets.Adapters.S3, bucket: "test-bucket"]
      location = Location.new("/some/path", config)

      inspected = inspect(location)

      assert inspected =~ ~s(path: "/some/path")
      refute inspected =~ "config:"
    end

    test "shows path field normally" do
      config = [adapter: Buckets.Adapters.Volume, bucket: "/tmp"]
      location = Location.new("/uploads/test.pdf", config)

      inspected = inspect(location)

      assert inspected =~ ~s(path: "/uploads/test.pdf")
    end
  end

  describe "new/2" do
    test "creates location with path and config" do
      config = [adapter: Buckets.Adapters.Volume, bucket: "/tmp"]
      location = Location.new("/test/path", config)

      assert location.path == "/test/path"
      assert location.config == config
    end

    test "creates location with s3 config" do
      config = [adapter: Buckets.Adapters.S3, bucket: "my-bucket", region: "us-east-1"]
      location = Location.new("/test/path", config)

      assert location.path == "/test/path"
      assert location.config == config
    end
  end
end
