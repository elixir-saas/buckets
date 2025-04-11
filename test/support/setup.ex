defmodule Buckets.Setup do
  import Buckets.UploadFixtures

  def setup_scope(_context) do
    %{scope: Ecto.UUID.generate()}
  end

  def setup_bucket(context, opts) do
    object = pdf_object()
    remote_path = Buckets.Util.build_object_path(object.filename, context.scope, opts)

    {:ok, _result} = Buckets.put(object, remote_path, opts)

    %{object: object}
  end
end
