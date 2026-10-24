if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Billboard.Install do
    @shortdoc "Installs billboard into a Phoenix site that has Ash"
    @moduledoc """
    #{@shortdoc}: its config, the site module and the modules billboard
    writes its resources into, a starter, the page layout, the cache,
    the uploads, the theme and the editor's assets, and the editor's
    route. It leaves alone anything that's there already, so it's safe to
    run again.

    It needs Ash and AshPostgres set up, and a signed-in live_session:

        mix igniter.install ash ash_postgres ash_phoenix --yes
        mix phx.gen.auth Accounts User users --live

    Then:

        mix billboard.install --home
        mix ash.codegen add_billboard
        mix ecto.migrate

    ## Options

      * `--editor-path` - where the editor is mounted, inside the
        live_session's scope. Defaults to `/admin/pages`.
      * `--live-session` - the signed-in live_session the editor joins:
        its `on_mount` gives the editor `current_scope`, whose user the
        editor acts as. Defaults to `require_authenticated_user`,
        `mix phx.gen.auth`'s.
      * `--home` - draws the home page with billboard: writes
        `MySiteWeb.BillboardPageLive`, which draws any of the site's
        pages for visitors, and routes `/` to it in place of
        `PageController`'s home.
    """
    use Igniter.Mix.Task

    alias Billboard.Install

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :billboard,
        example: "mix billboard.install --home",
        schema: [editor_path: :string, live_session: :string, home: :boolean],
        defaults: [
          editor_path: "/admin/pages",
          live_session: "require_authenticated_user",
          home: false
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      names = Install.names(igniter)

      case Install.ash_postgres_repo?(igniter, names.repo) do
        {igniter, true} ->
          igniter
          |> config(names)
          |> modules(names)
          |> Install.add_cache()
          |> notices()

        {igniter, false} ->
          Igniter.add_issue(
            igniter,
            "#{inspect(names.repo)} isn't an AshPostgres repo, and billboard keeps its pages " <>
              "with AshPostgres. Set up Ash first, with " <>
              "`mix igniter.install ash ash_postgres ash_phoenix --yes`, then run " <>
              "`mix billboard.install` again."
          )
      end
    end

    defp config(igniter, names) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:billboard)
      |> Igniter.Project.Config.configure_new("config.exs", :billboard, [:site], names.site)
      |> Igniter.Project.Config.configure(
        "config.exs",
        names.app,
        [:ash_domains],
        [names.pages],
        updater: &Igniter.Code.List.append_new_to_list(&1, names.pages)
      )
    end

    defp modules(igniter, names) do
      [
        {names.site, "site.ex.eex"},
        {names.pages, "domain.ex.eex"},
        {Module.concat(names.pages, Page), "page.ex.eex"},
        {Module.concat(names.pages, Version), "version.ex.eex"},
        {Module.concat(names.pages, Section), "section.ex.eex"},
        {Module.concat(names.pages, Content), "content.ex.eex"},
        {Module.concat(names.pages, Starter), "starter.ex.eex"}
      ]
      |> Enum.reduce(igniter, fn {module, template}, igniter ->
        Install.create_module(
          igniter,
          module,
          Install.template("billboard.install", template, names)
        )
      end)
    end

    defp notices(igniter) do
      Igniter.add_notice(igniter, """
      Billboard is installed. Write its tables' migrations, and run them:

          mix ash.codegen add_billboard
          mix ecto.migrate

      Then start the site, sign in, and open the editor. Billboard's
      getting started guide says what was written, and what's next.
      """)
    end
  end
else
  defmodule Mix.Tasks.Billboard.Install do
    @shortdoc "Installs billboard into a Phoenix site that has Ash"
    @moduledoc "#{@shortdoc}. It needs Igniter: see the error it raises."
    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.raise(
        "mix billboard.install needs Igniter. Add `{:igniter, \"~> 0.8\", only: [:dev, :test]}` " <>
          "to your deps, run mix deps.get, and run mix billboard.install again"
      )
    end
  end
end
