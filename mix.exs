defmodule Sqids.MixProject do
  use Mix.Project

  @version "0.1.3"
  @source_url "https://github.com/sqids/sqids-elixir"

  def project do
    mix_env = Mix.env()

    [
      app: :sqids,
      version: @version,
      description: description(),
      elixir: "~> 1.7",
      start_permanent: mix_env === :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(mix_env),
      elixirc_options: elixirc_options(mix_env),
      docs: docs(),
      test_coverage: [
        summary: [
          threshold: 93
        ]
      ],
      dialyzer: [plt_add_apps: [:ex_unit]],
      package: package()
    ]
  end

  defp description do
    "Generate YouTube-looking IDs from numbers"
  end

  defp deps do
    List.flatten([
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:recon, "~> 2.5", only: [:dev, :test], runtime: false},
      {:sqids_blocklist,
       github: "sqids/sqids-blocklist", branch: "main", only: :dev, runtime: false, app: false, compile: false},
      maybe_credo_dep(),
      maybe_dialyxir_dep(),
      maybe_styler_dep()
    ])
  end

  defp maybe_credo_dep do
    if elixir_vsn_match?("~> 1.12") do
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    else
      []
    end
  end

  defp maybe_dialyxir_dep do
    if elixir_vsn_match?("~> 1.12") do
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    else
      []
    end
  end

  defp maybe_styler_dep do
    if elixir_vsn_match?("~> 1.14") do
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false}
    else
      []
    end
  end

  defp elixirc_paths(env) do
    if env === :test do
      ["lib", "test/extra"]
    else
      ["lib"]
    end
  end

  defp elixirc_options(env) do
    if env === :test do
      [warnings_as_errors: true]
    else
      []
    end
  end

  defp docs do
    [
      main: "readme",
      name: "Sqids",
      source_ref: @version,
      canonical: "http://hexdocs.pm/sqids",
      source_url: @source_url,
      extras: [
        "CHANGELOG.md",
        "LICENSE",
        "README.md": [title: "Sqids"]
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Guilherme Andrade"],
      licenses: ["MIT"],
      links: %{
        "About Sqids" => "https://sqids.org/",
        "GitHub" => @source_url
      }
    ]
  end

  defp elixir_vsn_match?(requirement), do: Version.match?(System.version(), requirement)
end
