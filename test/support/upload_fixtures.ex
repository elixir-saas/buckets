defmodule Buckets.UploadFixtures do
  def pdf_object() do
    Buckets.Object.from_file(path!("simple.pdf"))
  end

  defp path!(file), do: Path.join(:code.priv_dir(:buckets), file)
end
