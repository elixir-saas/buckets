defmodule Buckets.MixProject do
  use Mix.Project

  def project do
    [
      app: :buckets,
      version: "1.0.0-rc.1",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  defp description() do
    "Cloud provider agnostic file storage."
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{}
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
      {:mime, "~> 2.0"},
      {:ecto, "~> 3.11"},
      {:plug, "~> 1.14"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, ">= 0.20.0"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.0"},
      {:req_s3, "~> 0.2.3"},
      {:jose, "~> 1.11"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
