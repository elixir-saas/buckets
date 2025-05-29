defmodule Buckets.Router do
  @scope "__buckets__"

  def scope(), do: @scope

  defmacro buckets_volume(cloud_module, opts \\ []) do
    {location, opts} = Keyword.pop(opts, :location)

    if !location do
      raise """
      `buckets_volume/1` requires the :location option to be set.

          Set :location to the location that you have configured with
          the `Buckets.Strategy.Volume` strategy.
      """
    end

    quote do
      scope unquote("/" <> @scope) do
        private = %{
          cloud_module: unquote(cloud_module),
          location: unquote(location),
          opts: unquote(opts)
        }

        get("/:bucket/*path", Buckets.Router.VolumeController, :get, private: private)
        put("/:bucket/*path", Buckets.Router.VolumeController, :put, private: private)
      end
    end
  end
end
