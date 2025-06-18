defmodule Buckets.Router do
  @scope "__buckets__"

  def scope(), do: @scope

  defmacro buckets_volume(cloud_module, opts \\ []) do
    quote do
      scope unquote("/" <> @scope) do
        private = %{
          cloud_module: unquote(cloud_module),
          opts: unquote(opts)
        }

        get("/:bucket/*path", Buckets.Router.VolumeController, :get, private: private)
        put("/:bucket/*path", Buckets.Router.VolumeController, :put, private: private)
      end
    end
  end
end
