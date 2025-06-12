defmodule Buckets.LocationTest do
  use ExUnit.Case, async: true

  alias Buckets.Location

  describe "inspect/1" do
    test "redacts config field" do
      location =
        Location.new("/some/path",
          adapter: Buckets.Adapters.S3,
          bucket: "my-bucket",
          access_key_id: "AKIAIOSFODNN7EXAMPLE",
          secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )

      inspected = inspect(location)

      assert inspected =~ ~s(path: "/some/path")
      refute inspected =~ "AKIAIOSFODNN7EXAMPLE"
      refute inspected =~ "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      refute inspected =~ "config:"
    end

    test "shows path field normally" do
      location = Location.new("/uploads/test.pdf", adapter: Buckets.Adapters.Volume)

      inspected = inspect(location)

      assert inspected =~ ~s(path: "/uploads/test.pdf")
    end
  end

  describe "new/2" do
    test "creates location with path and config" do
      config = [adapter: Buckets.Adapters.Volume, bucket: "test"]
      location = Location.new("/test/path", config)

      assert location.path == "/test/path"
      assert location.config == config
    end
  end
end
