defmodule Maizzlex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/example/maizzlex"

  def project do
    [
      app: :maizzlex,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:html2text, "~> 0.2"},
      {:igniter, "~> 0.6", optional: true},
      {:swoosh, "~> 1.14"}
    ]
  end

  defp description do
    "Reusable Maizzle + Swoosh email runtime and scaffolding"
  end

  defp package do
    [
      name: "maizzlex",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "docs/installation.md",
        "docs/configuration.md",
        "docs/theming.md",
        "docs/custom_adapters.md",
        "docs/workflow.md"
      ]
    ]
  end
end
