defmodule Buckets.Setup do
  import Buckets.UploadFixtures

  def setup_scope(_context) do
    %{scope: Ecto.UUID.generate()}
  end

  def setup_bucket(context, opts) do
    {:ok, object} = Buckets.put(pdf_upload(), context.scope, opts)
    %{object: object}
  end
end
