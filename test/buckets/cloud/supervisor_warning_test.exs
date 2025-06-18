defmodule Buckets.Cloud.SupervisorWarningTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Buckets.Cloud.Supervisor

  describe "supervisor warnings" do
    test "logs warning when adapter needs no supervision" do
      # Create a mock cloud module that uses Volume adapter
      defmodule TestVolumeCloud do
        def config do
          [adapter: Buckets.Adapters.Volume, bucket: "/tmp"]
        end
      end

      # Should log a warning since Volume adapter returns nil for child_spec
      log =
        capture_log(fn ->
          # We can't easily test the full supervisor init without starting processes,
          # but we can test the warning logic by calling init directly
          {:ok, {_, []}} = Supervisor.init(TestVolumeCloud)
        end)

      assert log =~
               "Cloud supervisor for Buckets.Cloud.SupervisorWarningTest.TestVolumeCloud has no children to supervise"

      assert log =~ "Buckets.Adapters.Volume adapter doesn't require any supervised processes"
      assert log =~ "Consider removing"
    end

    test "no warning when adapter needs supervision" do
      # Create a mock cloud module that uses GCS adapter
      defmodule TestGCSCloud do
        def config do
          [
            adapter: Buckets.Adapters.GCS,
            bucket: "test",
            # Will fail but that's ok
            service_account_credentials: "{\"invalid\": \"json\"}"
          ]
        end
      end

      # Should not log a warning even though GCS will fail to start due to invalid credentials
      # The important thing is that GCS adapter tries to return a child spec (even if it's nil due to credential failure)
      log =
        capture_log(fn ->
          {:ok, {_, _children}} = Supervisor.init(TestGCSCloud)
        end)

      # Should not contain the "no children to supervise" warning
      refute log =~ "has no children to supervise"
    end
  end
end
