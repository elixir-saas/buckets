defmodule Buckets.AdapterTest do
  use ExUnit.Case, async: true

  describe "adapter child_spec/2 callback" do
    test "Volume adapter does not export child_spec/2" do
      # Volume doesn't need supervised processes
      refute function_exported?(Buckets.Adapters.Volume, :child_spec, 2)
    end

    test "S3 adapter does not export child_spec/2" do
      # S3 doesn't need supervised processes
      refute function_exported?(Buckets.Adapters.S3, :child_spec, 2)
    end

    test "GCS adapter returns child spec for auth server" do
      # GCS needs auth servers, so it exports child_spec/2
      assert function_exported?(Buckets.Adapters.GCS, :child_spec, 2)

      # Test with a minimal config
      config = [
        adapter: Buckets.Adapters.GCS,
        bucket: "test-bucket",
        service_account_credentials: "dummy"
      ]

      result = Buckets.Adapters.GCS.child_spec(config, TestCloud.GCS)

      # Should return a proper child spec
      assert %{
               id: {Buckets.Adapters.GCS.AuthServer, TestCloud.GCS},
               start: {Buckets.Adapters.GCS.AuthServer, :start_link, [[cloud: TestCloud.GCS]]},
               restart: :permanent
             } = result
    end
  end

  describe "Cloud.Supervisor uses adapter child_spec" do
    test "supervisor checks for child_spec/2 existence" do
      # The supervisor checks if adapters export child_spec/2
      # Only GCS should export it
      assert function_exported?(Buckets.Adapters.GCS, :child_spec, 2)
      refute function_exported?(Buckets.Adapters.Volume, :child_spec, 2)
      refute function_exported?(Buckets.Adapters.S3, :child_spec, 2)
    end
  end
end
