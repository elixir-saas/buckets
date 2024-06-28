defmodule Buckets.Object do
  @type t :: %__MODULE__{
          filename: String.t(),
          content_type: String.t(),
          object_url: String.t(),
          object_path: String.t()
        }

  defstruct [:filename, :content_type, :object_url, :object_path]
end
