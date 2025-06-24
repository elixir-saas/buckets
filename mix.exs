defmodule Buckets.MixProject do
  use Mix.Project

  @version "1.0.0-rc.3"
  @source_url "https://github.com/elixir-saas/buckets"

  def project do
    [
      app: :buckets,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: description(),
      package: package(),

      # Docs,
      name: "Buckets",
      docs: docs()
    ]
  end

  defp description() do
    "Cloud provider agnostic file storage."
  end

  defp package() do
    [
      maintainers: ["Justin Tormey"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(.formatter.exs mix.exs README.md CHANGELOG.md lib priv/logo.png priv/simple.pdf)
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

  defp docs do
    [
      main: "Buckets",
      source_ref: "v#{@version}",
      logo: "priv/logo.png",
      extra_section: "GUIDES",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      assets: %{"priv" => "assets"},
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: [
        "Core APIs": [
          Buckets,
          Buckets.Cloud,
          Buckets.Object,
          Buckets.Location,
          Buckets.SignedURL
        ],
        Adapters: [
          Buckets.Adapters.Volume,
          Buckets.Adapters.S3,
          Buckets.Adapters.GCS
        ],
        "Adapter Specification": [
          Buckets.Adapter
        ],
        Router: [
          Buckets.Router,
          Buckets.Router.VolumeController
        ],
        Utilities: [
          Buckets.Util,
          Buckets.Telemetry
        ],
        "Internal APIs": [
          Buckets.Cloud.Dynamic,
          Buckets.Cloud.Operations,
          Buckets.Cloud.Supervisor,
          Buckets.Adapters.GCS.Auth,
          Buckets.Adapters.GCS.AuthServer,
          Buckets.Adapters.GCS.Signature,
          Buckets.Location.NotConfigured
        ]
      ]
    ]
  end

  defp extras do
    [
      {"CHANGELOG.md", [title: "Changelog"]},

      # Introduction
      "guides/introduction/getting-started.md",
      "guides/introduction/core-concepts.md",

      # Adapter Guides
      "guides/adapters/writing-custom-adapters.md",

      # How-To Guides
      "guides/howtos/file-uploads.md",
      "guides/howtos/direct-uploads-liveview.md",
      "guides/howtos/signed-urls.md",
      "guides/howtos/multi-cloud-setup.md",
      "guides/howtos/dynamic-configuration.md",
      "guides/howtos/error-handling.md",
      "guides/howtos/testing.md",

      # Advanced Topics
      "guides/advanced/telemetry-and-monitoring.md"
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      Adapters: ~r/guides\/adapters\/.?/,
      "How-To Guides": ~r/guides\/howtos\/.?/,
      "Advanced Topics": ~r/guides\/advanced\/.?/
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
