defmodule Sqids.MixProject do
  use Mix.Project

  def project do
    [
      app: :sqids,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
          # FIXME
          threshold: 0
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        # FIXME
        :crypto
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:jason, "~> 1.4", only: :dev, runtime: false},
      {:recon, "~> 2.5", only: :dev, runtime: false},
      {:styler, "~> 0.8", only: [:dev, :test], runtime: false}
    ]
  end
end
