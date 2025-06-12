ExUnit.start(exclude: [:live])

# Start GCS auth supervisor for tests
{:ok, _pid} = Buckets.Strategy.GCS.AuthSupervisor.start_link(cloud: TestCloud)
