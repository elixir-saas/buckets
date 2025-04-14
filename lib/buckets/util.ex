defmodule Buckets.Util do
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
