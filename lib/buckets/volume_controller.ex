defmodule Buckets.VolumeController do
  use Phoenix.Controller

  def put(conn, %{"path" => path, "bucket" => bucket}) do
    if bucket != conn.private.bucket_path do
      raise """
      The `"bucket"` parameter must match `:path` option given to `buckets_volume/1`.

      Check that the configuration you are using to generate the volume upload URL matches
      the value configured in your Router module.
      """
    end

    path = Path.join(bucket, path)
    File.mkdir_p!(Path.dirname(path))

    conn
    |> stream_body()
    |> Enum.into(File.stream!(path))

    send_resp(conn, 200, "")
  end

  ## Private

  defp stream_body(conn) do
    Stream.resource(
      fn -> conn end,
      fn conn ->
        case Plug.Conn.read_body(conn) do
          {:ok, "", conn} -> {:halt, conn}
          {:ok, body, conn} -> {[body], conn}
          {:more, binary, conn} -> {[binary], conn}
        end
      end,
      fn _conn -> nil end
    )
  end
end
