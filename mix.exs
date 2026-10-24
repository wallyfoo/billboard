defmodule Billboard.MixProject do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :billboard,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      # Colocated hooks reach a site's bundle only if billboard runs
      # LiveView's compiler itself.
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      aliases: aliases(),
      deps: deps(),
      name: "Billboard",
      source_url: "https://github.com/wallyfoo/billboard",
      docs: docs()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  # The guides' worked examples are compiled and tested with the library.
  defp elixirc_paths(:test), do: ["lib", "test/support", "guides/examples/lib"]
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
      # `Billboard.ComponentCase` checks out the site's repo in the SQL
      # sandbox. AshPostgres brings it to every site already.
      {:ecto_sql, "~> 3.13"},
      {:lazy_html, "~> 0.1", only: :test},
      # The generators (`mix billboard.install` and
      # `mix billboard.gen.component`) are Igniter tasks. A site has
      # Igniter in dev and test; without it, the tasks say how to add it.
      {:igniter, "~> 0.8.4", optional: true},
      # The generators' tests build a Phoenix project in memory.
      {:phx_new, "~> 1.8", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      # Spark's formatter uses Sourceror, and Igniter needs it in every
      # env, so it can't be dev-and-test only here. Optional, so a site
      # gets it only with Igniter, which brings its own.
      {:sourceror, "~> 1.8", optional: true}
    ]
  end

  defp docs do
    [
      main: "getting-started",
      source_ref: "v#{@version}",
      extras: [
        "guides/getting-started.md",
        "guides/writing-a-component.md",
        "guides/parts.md",
        "guides/theming.md",
        "guides/page-kinds-and-bound-sections.md",
        "guides/why-the-rules-exist.md"
      ],
      groups_for_extras: [Guides: ~r{guides/}]
    ]
  end

  # The test site's tables live in the test database, which `mix test`
  # creates and migrates first, as a Phoenix app's alias does.
  defp aliases, do: [test: ["ash.setup --quiet", "test"]]
end
