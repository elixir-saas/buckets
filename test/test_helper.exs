ExUnit.start(exclude: [:live])

sa_json =
  "secret/elixir-saas-82a32641f1b6.json"
  |> File.read!()
  |> Jason.decode!()

{:ok, _pid} = Goth.start_link(name: GothTest, source: {:service_account, sa_json})
