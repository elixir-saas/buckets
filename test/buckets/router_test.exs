defmodule Buckets.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule TestRouter do
    use Phoenix.Router

    import Buckets.Router

    buckets_volume(TestCloud.Volume)
  end

  describe "buckets_volume/2" do
    test "GET route matches bucket with slashes" do
      bucket = TestCloud.Volume.config()[:bucket] |> Base.url_encode64(padding: false)

      route_info =
        Phoenix.Router.route_info(TestRouter, "GET", "/__buckets__/#{bucket}/some/file.pdf", "")

      assert route_info.plug == Buckets.Router.VolumeController
      assert route_info.plug_opts == :get
      assert route_info.path_params == %{"path" => ["some", "file.pdf"]}
    end

    test "PUT route matches bucket with slashes" do
      bucket = TestCloud.Volume.config()[:bucket] |> Base.url_encode64(padding: false)

      route_info =
        Phoenix.Router.route_info(TestRouter, "PUT", "/__buckets__/#{bucket}/some/file.pdf", "")

      assert route_info.plug == Buckets.Router.VolumeController
      assert route_info.plug_opts == :put
      assert route_info.path_params == %{"path" => ["some", "file.pdf"]}
    end

    test "routes do not match wrong bucket" do
      route_info =
        Phoenix.Router.route_info(
          TestRouter,
          "GET",
          "/__buckets__/wrong_bucket/some/file.pdf",
          ""
        )

      assert route_info == :error
    end

    test "route includes correct path pattern" do
      bucket = TestCloud.Volume.config()[:bucket] |> Base.url_encode64(padding: false)

      route_info =
        Phoenix.Router.route_info(TestRouter, "GET", "/__buckets__/#{bucket}/some/file.pdf", "")

      assert route_info.route == "/__buckets__/#{bucket}/*path"
    end
  end

  describe "bucket encoding" do
    test "base64 encodes bucket for URL safety" do
      bucket = TestCloud.Volume.config()[:bucket]
      encoded = Base.url_encode64(bucket, padding: false)

      # Encoded bucket is URL-safe (no slashes)
      refute String.contains?(encoded, "/")

      # Can decode back to original
      assert Base.url_decode64!(encoded, padding: false) == bucket
    end
  end
end
