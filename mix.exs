defmodule Sqids.MixProject do
  use Mix.Project

  @source_url "https://github.com/sqids/sqids-elixir"

  def project do
    [
      app: :sqids,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: true
      ],
      docs: [
        main: "Sqids",
        extras: [
          "CHANGELOG.md",
          "LICENSE"
        ]
      ],
      test_coverage: [
        summary: [
          threshold: 90
        ]
      ],
      package: package()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    List.flatten([
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:recon, "~> 2.5", only: [:dev, :test], runtime: false},
      {:sqids_blocklist,
       github: "sqids/sqids-blocklist", branch: "main", only: :dev, runtime: false, app: false, compile: false},
      maybe_styler_dep()
    ])
  end

  defp maybe_styler_dep do
    if Version.match?(System.version(), "~> 1.14") do
      {:styler, "~> 0.8", only: [:dev, :test], runtime: false}
    else
      []
    end
  end

  defp elixirc_paths(env) do
    if env == :test do
      ["lib", "test/extra"]
    else
      ["lib"]
    end
  end

  defp package do
    [
      maintainers: ["Guilherme Andrade"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
