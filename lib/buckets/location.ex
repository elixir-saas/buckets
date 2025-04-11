defmodule Buckets.Location do
  @type t :: %__MODULE__{
          path: String.t(),
          config: Keyword.t()
        }

  defstruct [:path, :config]

  defmodule NotConfigured do
    defstruct []
  end

  def new(path, config) do
    %__MODULE__{
      path: path,
      config: config
    }
  end
end
