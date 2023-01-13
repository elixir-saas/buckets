defmodule Buckets.UploadFixtures do
  def pdf_upload() do
    %Buckets.Upload{
      path: path!("simple.pdf"),
      filename: "simple.pdf",
      content_type: "application/pdf"
    }
  end

  defp path!(file), do: Path.join(:code.priv_dir(:buckets), file)
end
