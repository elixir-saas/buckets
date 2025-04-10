defmodule Buckets.Location do
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
