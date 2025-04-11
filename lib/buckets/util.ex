defmodule Buckets.Util do
  @spec build_object_path(String.t(), Buckets.Strategy.scope(), Keyword.t()) :: String.t()
  def build_object_path(filename, scope, opts) do
    path = Keyword.get(opts, :path, "")
    object_path_parts = [path, object_id(scope), filename]

    object_path_parts
    |> Path.join()
    |> String.trim_leading("/")
  end

  @spec object_id(Buckets.Strategy.scope()) :: String.t()
  def object_id(scope) when is_binary(scope), do: scope
  def object_id(%{id: scope}) when is_binary(scope), do: scope

  @spec size(String.t()) :: integer()
  def size(path) when is_binary(path) do
    File.stat!(path).size
  end

  @spec normalize_filename(String.t()) :: String.t()
  def normalize_filename(filename) do
    filename
    |> String.replace(~r/\s/, "_")
    |> String.replace(~r/[^\.a-zA-Z0-9_-]/, "")
  end
end
