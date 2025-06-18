ExUnit.start(exclude: [:live])

# Only start auth server for cloud using GCS adapter
{:ok, _pid} = TestCloud.GCS.start_link()
