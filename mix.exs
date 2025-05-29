defmodule Buckets.MixProject do
  use Mix.Project

  def project do
    [
      app: :buckets,
      version: "0.2.0",
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
      {:ex_aws_s3, "~> 2.0"},
      {:google_api_storage, "~> 0.34"},
      {:gcs_signed_url, "~> 0.4"},
      {:goth, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
