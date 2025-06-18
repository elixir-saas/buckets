defmodule Buckets.Router.VolumeController do
  use Phoenix.Controller

  plug(:validate_bucket)
  plug(:validate_signature)

  def get(conn, %{"path" => path}) do
    cloud_module = conn.private.cloud_module

    object = Buckets.Object.new(nil, List.last(path), location: {Path.join(path), cloud_module})

    binary = cloud_module.read!(object)

    conn =
      if max_age = Keyword.get(conn.private.opts, :cache_control) do
        put_resp_header(conn, "cache-control", "max-age=#{max_age}")
      else
        conn
      end

    send_download(conn, {:binary, binary}, filename: object.filename)
  end

  def put(conn, %{"bucket" => bucket, "path" => path} = params) do
    if params["verb"] != "PUT" do
      raise """
      Tried to upload file to a URL not designated for uploads.
      """
    end

    path = Path.join([bucket | path])
    File.mkdir_p!(Path.dirname(path))

    conn
    |> stream_body()
    |> Stream.into(File.stream!(path))
    |> Stream.run()

    send_resp(conn, 200, "")
  end

  ## Plugs

  defp validate_bucket(conn, _opts) do
    cloud_module = conn.private.cloud_module

    if cloud_module.config()[:bucket] == conn.path_params["bucket"] do
      conn
    else
      raise """
      The `"bucket"` parameter must match the `:bucket` configured for: #{inspect(cloud_module)}.

          Check that the configuration you are using to generate the volume upload URL matches
          the cloud module configured in your Router module.
      """
    end
  end

  defp validate_signature(conn, _opts) do
    import Buckets.Adapters.Volume, only: [verify_signed_path: 3]

    config = conn.private.cloud_module.config()

    %{path_info: path, query_params: params} = conn

    endpoint = config[:endpoint]

    if endpoint == nil or verify_signed_path(path, params, endpoint) do
      conn
    else
      raise """
      Request to buckets_volume failed signature verification.
      """
    end
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
