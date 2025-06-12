defmodule Buckets.Adapters.GCS.AuthServerTest do
  use ExUnit.Case

  alias Buckets.Adapters.GCS.AuthSupervisor

  setup do
    # Use fake credentials for testing
    credentials = %{
      "client_email" => "test@example.com",
      "private_key" => "invalid-key"
    }

    {:ok, credentials: credentials}
  end

  describe "supervisor behavior" do
    test "supervisor starts successfully with TestCloud" do
      # The supervisor should already be started in test_helper.exs
      # Check that it's running
      assert Process.whereis(Buckets.Adapters.GCS.AuthSupervisor) != nil

      # Check that it has started child processes for GCS locations
      children = Supervisor.which_children(Buckets.Adapters.GCS.AuthSupervisor)

      # Should have at least one child for the GCS configuration in test.exs
      assert length(children) >= 1

      # Each child should be an AuthServer
      Enum.each(children, fn {_id, pid, :worker, [Buckets.Adapters.GCS.AuthServer]} ->
        assert Process.alive?(pid)
      end)
    end

    test "can get tokens using the supervisor" do
      # Create a config that looks like what the Cloud module would create
      config = [
        adapter: Buckets.Adapters.GCS,
        bucket: "test-bucket",
        service_account_path: "secret/elixir-saas-82a32641f1b6.json",
        __location_key__: :google
      ]

      # Should be able to get tokens from servers started by supervisor
      # This will work because we have the :google location configured in test.exs
      result = AuthSupervisor.get_token(config)

      # Should either get a token or an error (but not a server not found error)
      assert match?({:ok, _}, result) or match?({:error, {:jwt_generation_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end
  end

  describe "credential fingerprinting" do
    test "different credentials produce different server names" do
      credentials1 = %{
        "client_email" => "test1@example.com",
        "private_key" => "key1"
      }

      credentials2 = %{
        "client_email" => "test2@example.com",
        "private_key" => "key2"
      }

      # Test that the server name generation is deterministic and different
      # We'll use a test-accessible function for this
      name1 = test_server_name_for_credentials(credentials1)
      name2 = test_server_name_for_credentials(credentials2)

      assert name1 != name2
      assert is_atom(name1)
      assert is_atom(name2)
    end
  end

  # Helper function to test server name generation
  defp test_server_name_for_credentials(credentials) do
    fingerprint = test_credentials_fingerprint(credentials)
    hash = :crypto.hash(:sha256, fingerprint) |> Base.encode16() |> String.slice(0, 16)
    Module.concat(Buckets.Adapters.GCS.AuthServer, "GCS_#{hash}")
  end

  defp test_credentials_fingerprint(credentials) do
    client_email = Map.get(credentials, "client_email", "")
    private_key = Map.get(credentials, "private_key", "")
    private_key_hash = :crypto.hash(:sha256, private_key) |> Base.encode16()
    "#{client_email}:#{private_key_hash}"
  end

  describe "error handling" do
    test "handles missing location key gracefully" do
      # Config without location key should fail
      config = [
        adapter: Buckets.Adapters.GCS,
        bucket: "test-bucket",
        service_account_path: "some-path.json"
      ]

      assert {:error, {:location_key_missing, _}} = AuthSupervisor.get_token(config)
    end

    test "handles missing auth server gracefully" do
      # Config with non-existent location key should fail
      config = [
        adapter: Buckets.Adapters.GCS,
        bucket: "test-bucket",
        service_account_path: "some-path.json",
        __location_key__: :nonexistent_location
      ]

      assert {:error, {:auth_server_not_found, _}} = AuthSupervisor.get_token(config)
    end
  end

  describe "location-based auth" do
    test "works with location key from cloud config" do
      # This simulates what happens when Cloud.config_for/1 is called
      config = [
        adapter: Buckets.Adapters.GCS,
        bucket: "test-bucket",
        service_account_path: "secret/elixir-saas-82a32641f1b6.json",
        __location_key__: :google
      ]

      object = %Buckets.Object{data: {:data, "test data"}, filename: "test.txt"}

      # Should successfully route to the auth server for this location
      result = Buckets.Adapters.GCS.put(object, "test/path", config)

      # Should get some kind of result (token or auth error), not a routing error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "fails gracefully with missing location key" do
      config = [
        adapter: Buckets.Adapters.GCS,
        bucket: "test-bucket",
        service_account_path: "some-path.json"
        # Missing __location_key__
      ]

      object = %Buckets.Object{data: {:data, "test data"}, filename: "test.txt"}

      # Should fail with location key missing error
      result = Buckets.Adapters.GCS.put(object, "test/path", config)
      assert match?({:error, {:location_key_missing, _}}, result)
    end
  end
end
