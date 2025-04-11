defmodule Buckets.Cloud do
  defmacro __using__(opts) do
    otp_app = opts[:otp_app]
    default_location = opts[:default_location]

    quote do
      def insert(object_or_path, opts \\ []) do
        Buckets.Cloud.Operations.insert(__MODULE__, object_or_path, opts)
      end

      def delete(object) do
        Buckets.Cloud.Operations.delete(object)
      end

      def read(object) do
        Buckets.Cloud.Operations.read(object)
      end

      def load(object, opts \\ []) do
        Buckets.Cloud.Operations.load(__MODULE__, object, opts)
      end

      def unload(object) do
        Buckets.Cloud.Operations.unload(object)
      end

      def live_upload(entry, opts \\ []) do
        Buckets.Cloud.Operations.live_upload(__MODULE__, entry, opts)
      end

      def insert!(object_or_path, opts \\ []) do
        Buckets.Cloud.Operations.insert!(__MODULE__, object_or_path, opts)
      end

      def delete!(object) do
        Buckets.Cloud.Operations.delete!(object)
      end

      def read!(object) do
        Buckets.Cloud.Operations.read!(object)
      end

      def load!(object, opts \\ []) do
        Buckets.Cloud.Operations.load!(__MODULE__, object, opts)
      end

      def live_upload!(entry, opts \\ []) do
        Buckets.Cloud.Operations.live_upload!(__MODULE__, entry, opts)
      end

      ## Overridable

      def tmp_dir() do
        System.tmp_dir!()
      end

      def normalize_filename(filename) do
        Buckets.Util.normalize_filename(filename)
      end

      defoverridable tmp_dir: 0, normalize_filename: 1

      ## Config

      def config_for(:default), do: config_for(unquote(default_location))
      def config_for(location), do: Keyword.fetch!(config(:locations), location)

      defp config(key), do: Keyword.fetch!(config(), key)
      defp config(), do: Application.fetch_env!(unquote(otp_app), __MODULE__)
    end
  end
end
