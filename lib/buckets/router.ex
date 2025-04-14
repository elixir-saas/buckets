defmodule Buckets.Router do
  defmacro buckets_volume(opts \\ []) do
    bucket_path =
      opts[:path] ||
        raise """
        `buckets_volume/1` requires the :path option to be set.

            Set :path to the local directory that should serve as the base
            for files uploaded using `Buckets.Strategy.Volume`.
        """

    quote do
      scope "/__buckets__" do
        put("/volume", Buckets.Router.VolumeController, :put,
          private: %{bucket_path: unquote(bucket_path)}
        )
      end
    end
  end
end
