ExUnit.start(exclude: [:live])

# Start GCS auth supervisor for tests
{:ok, _pid} = Buckets.Adapters.GCS.AuthSupervisor.start_link(cloud: TestCloud)
