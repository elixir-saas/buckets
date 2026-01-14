defmodule Buckets.Router.VolumeController do
  @moduledoc """
  Phoenix controller for handling local file uploads and downloads in development.

  This controller is automatically used by the `Buckets.Router.buckets_volume/2`
  macro to handle Volume adapter file operations.

  ## Endpoints

  - `get/2` - Downloads files from the local filesystem
  - `put/2` - Uploads files to the local filesystem with signature validation

  For usage and configuration, see `Buckets.Router`.
  """
  use Phoenix.Controller, formats: []

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

  def put(conn, %{"path" => path} = params) do
    if params["verb"] != "PUT" do
      raise """
      Tried to upload file to a URL not designated for uploads.
      """
    end

    bucket = conn.private.cloud_module.config()[:bucket]
    path = Path.join([bucket | path])
    File.mkdir_p!(Path.dirname(path))

    conn
    |> stream_body()
    |> Stream.into(File.stream!(path))
    |> Stream.run()

    send_resp(conn, 200, "")
  end

  ## Plugs

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
