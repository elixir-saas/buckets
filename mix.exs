defmodule Buckets.MixProject do
  use Mix.Project

  def project do
    [
      app: :buckets,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.11"},
      {:plug, "~> 1.14.0"},
      {:phoenix_live_view, "~> 0.20"},
      {:jason, "~> 1.4"},
      {:google_api_storage, "~> 0.34"},
      {:gcs_signed_url, "~> 0.4"},
      {:goth, "~> 1.3"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
