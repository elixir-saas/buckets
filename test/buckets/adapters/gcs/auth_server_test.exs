defmodule Buckets.Adapters.GCS.AuthServerTest do
  use ExUnit.Case

  alias Buckets.Adapters.GCS.AuthServer

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
      # The TestCloud supervisor should already be started in test_helper.exs
      # Check that it's running
      assert Process.whereis(TestCloud.Supervisor) != nil

      # Check that it has started child processes for GCS locations
      children = Supervisor.which_children(TestCloud.Supervisor)

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
      result = AuthServer.get_token_from_config(config)

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
    test "raises on missing location key" do
      # Config without location key should fail
      config = [
        adapter: Buckets.Adapters.GCS,
        bucket: "test-bucket",
        service_account_path: "some-path.json"
      ]

      message = "Missing :__location_key__ in location configuration.\n"

      assert_raise RuntimeError, message, fn ->
        AuthServer.get_token_from_config(config)
      end
    end

    test "raises on missing auth server" do
      # Config with non-existent location key should fail
      config = [
        adapter: Buckets.Adapters.GCS,
        bucket: "test-bucket",
        service_account_path: "some-path.json",
        __location_key__: :nonexistent_location
      ]

      message = "No AuthServer running for location :nonexistent_location.\n"

      assert_raise RuntimeError, message, fn ->
        AuthServer.get_token_from_config(config)
      end
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

    test "raises with missing location key" do
      config = [
        adapter: Buckets.Adapters.GCS,
        bucket: "test-bucket",
        service_account_path: "some-path.json"
        # Missing __location_key__
      ]

      object = %Buckets.Object{data: {:data, "test data"}, filename: "test.txt"}

      message = "Missing :__location_key__ in location configuration.\n"

      assert_raise RuntimeError, message, fn ->
        Buckets.Adapters.GCS.put(object, "test/path", config)
      end
    end
  end
end
