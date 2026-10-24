defmodule Billboard.MixProject do
  use Mix.Project

  def project do
    [
      app: :billboard,
      version: "0.3.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      # Colocated hooks reach a site's bundle only if billboard runs
      # LiveView's compiler itself.
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
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
      # The editor's forms are `AshPhoenix.Form`s.
      {:ash_phoenix, "~> 2.3"},
      {:spark, "~> 2.7"},
      {:phoenix_pubsub, "~> 2.1"},
      # `Billboard.Errors.Refused` is a Splode error; Ash requires the same.
      {:splode, "~> 0.3"},
      # Ash's policies need a SAT solver; this one is plain Elixir.
      {:simple_sat, "~> 0.1"},
      # Renderers are function components; the theme and the editor are
      # drawn with them.
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.1"},
      {:jason, "~> 1.2"},
      # Words a site types are Markdown.
      {:mdex, "~> 0.14.2"},
      # `Billboard.Plugs.UploadsStatic` is a Plug.
      {:plug, "~> 1.15"},
      # Uploads are named with `Ecto.UUID`.
      {:ecto, "~> 3.14"},
      {:lazy_html, "~> 0.1", only: :test},
      {:sourceror, "~> 1.8", only: [:dev, :test]}
    ]
  end

  # The test site's tables live in the test database, which `mix test`
  # creates and migrates first, as a Phoenix app's alias does.
  defp aliases, do: [test: ["ash.setup --quiet", "test"]]
end
