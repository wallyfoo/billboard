defmodule Billboard.MixProject do
  use Mix.Project

  def project do
    [
      app: :billboard,
      version: "0.2.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ash, "~> 3.33"},
      {:ash_postgres, "~> 2.13"},
      {:spark, "~> 2.7"},
      {:phoenix_pubsub, "~> 2.1"},
      # `Billboard.Errors.Refused` is a Splode error; Ash requires the same.
      {:splode, "~> 0.3"},
      # Ash's policies need a SAT solver; this one is plain Elixir.
      {:simple_sat, "~> 0.1"},
      {:sourceror, "~> 1.8", only: [:dev, :test]}
    ]
  end

  # The test site's tables live in the test database, which `mix test`
  # creates and migrates first, as a Phoenix app's alias does.
  defp aliases, do: [test: ["ash.setup --quiet", "test"]]
end
