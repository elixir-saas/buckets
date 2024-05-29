defmodule Buckets.SignedURL do
  defstruct [:path, :filename, :url]

  @type t() :: %__MODULE__{
          path: String.t(),
          filename: String.t(),
          url: String.t()
        }

  def to_string(signed_url), do: signed_url.url

  defimpl String.Chars do
    defdelegate to_string(url), to: Buckets.SignedURL
  end

  defimpl Jason.Encoder do
    def encode(url, opts), do: Jason.Encode.string(to_string(url), opts)
  end
end
