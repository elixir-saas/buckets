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

    test "creates location with Cloud module" do
      location = Location.new("/test/path", TestCloud)

      assert location.path == "/test/path"
      assert location.config == TestCloud
    end
  end

  describe "get_config/1" do
    test "returns keyword list config as-is" do
      config = [adapter: Buckets.Adapters.Volume, bucket: "/tmp"]
      location = Location.new("/test/path", config)

      assert Location.get_config(location) == config
    end

    test "calls config/0 on Cloud module" do
      # Ensure TestCloud module is loaded
      Code.ensure_loaded!(TestCloud)

      location = Location.new("/test/path", TestCloud)

      # TestCloud.config() returns the actual configuration
      config = Location.get_config(location)
      assert is_list(config)
      assert config[:adapter] == Buckets.Adapters.Volume
    end

    test "raises for invalid module without config/0" do
      # Create a location with a module that doesn't have config/0
      location = Location.new("/test/path", String)

      assert_raise ArgumentError, ~r/Expected String to be a Cloud module/, fn ->
        Location.get_config(location)
      end
    end
  end
end
