ExUnit.start(exclude: [:live])

# Start TestCloud supervisor for tests
{:ok, _pid} = TestCloud.start_link()
