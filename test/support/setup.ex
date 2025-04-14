defmodule Buckets.Setup do
  import Buckets.UploadFixtures

  def setup_scope(_context) do
    %{scope: Ecto.UUID.generate()}
  end

  def setup_bucket(context, opts) do
    object = pdf_object()
    remote_path = build_object_path(object.filename, context.scope, opts)

    {:ok, _result} = Buckets.put(object, remote_path, opts)

    %{object: object}
  end

  ## Private

  @type scope() :: String.t() | %{id: String.t()}

  @spec build_object_path(String.t(), scope(), Keyword.t()) :: String.t()
  defp build_object_path(filename, scope, opts) do
    path = Keyword.get(opts, :path, "")
    object_path_parts = [path, object_id(scope), filename]

    object_path_parts
    |> Path.join()
    |> String.trim_leading("/")
  end

  @spec object_id(scope()) :: String.t()
  defp object_id(scope) when is_binary(scope), do: scope
  defp object_id(%{id: scope}) when is_binary(scope), do: scope
end
