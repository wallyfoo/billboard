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
      * `--live-session` - the live_session the editor joins, which must
        be one only signed-in users can join: its `on_mount` gives the
        editor `current_scope`, whose user the editor acts as, and the
        editor checks no permission of its own, so everyone the session
        lets in can edit and publish every page. The installer mounts it
        only in a session whose `on_mount` runs `:require_authenticated`,
        or whose scope pipes through `:require_authenticated_user`, and
        never in `:current_user`, which is for everyone. Defaults to
        `require_authenticated_user`, `mix phx.gen.auth`'s, which lets in
        every signed-in user, and `mix phx.gen.auth`'s registration lets
        anyone sign up: before you deploy, close registration, or mount
        the editor in a session only your admins can join.
      * `--home` - draws the home page with billboard: writes
        `MySiteWeb.BillboardPageLive`, which draws any of the site's
        pages for visitors, and routes `/` to it in place of
        `PageController`'s home, inside `mix phx.gen.auth`'s
        `live_session :current_user`, since the root layout reads
        `@current_scope`.
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
      options = igniter.args.options
      {igniter, names} = Install.names(igniter)

      if names.repo do
        igniter
        |> config(names)
        |> modules(names)
        |> Install.add_layout(names)
        |> Install.mount_editor(options)
        |> home(names, options[:home])
        |> Install.plug_uploads(names)
        |> uploads()
        |> assets()
        |> Install.add_cache()
        |> notices(names)
      else
        Igniter.add_issue(
          igniter,
          "#{names.prefix} has no AshPostgres repo, and billboard keeps its pages " <>
            "with AshPostgres. Set up Ash first, with " <>
            "`mix igniter.install ash ash_postgres ash_phoenix --yes`, then run " <>
            "`mix billboard.install` again."
        )
      end
    end

    defp config(igniter, names) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:billboard)
      |> Install.configure_new("config.exs", :billboard, :site, names.site)
      |> domains(names)
    end

    defp domains(igniter, %{pages: nil}), do: igniter

    defp domains(igniter, names) do
      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        names.app,
        [:ash_domains],
        [names.pages],
        updater: &Igniter.Code.List.append_new_to_list(&1, names.pages)
      )
    end

    # A site that has billboard under a domain this can't read keeps its
    # own modules, and gets no second domain.
    defp modules(igniter, %{pages: nil} = names) do
      Igniter.add_warning(
        igniter,
        "Couldn't read the `domain:` of #{inspect(names.site)}'s `use Billboard.Site`, so " <>
          "billboard's domain and resources are left as they are."
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

    defp home(igniter, _names, false), do: igniter

    defp home(igniter, %{pages: nil} = names, true) do
      Igniter.add_warning(
        igniter,
        "Couldn't read #{inspect(names.site)}'s domain, so `--home` wrote no page. Write " <>
          "a LiveView that draws `Billboard.Sections.page/1`, and route `/` to it."
      )
    end

    defp home(igniter, names, true), do: Install.route_home(igniter, names)

    # Where uploaded photographs go: the site's priv in dev, a directory
    # tests empty, and, in production, a volume that outlives a deploy.
    defp uploads(igniter) do
      expand = &{:code, Sourceror.parse_string!(~s|Path.expand("#{&1}", __DIR__)|)}

      igniter
      |> Install.configure_new("config.exs", :billboard, :uploads_dir, expand.("../priv/uploads"))
      |> Install.configure_new(
        "test.exs",
        :billboard,
        :uploads_dir,
        expand.("../tmp/test-uploads")
      )
      |> runtime_uploads()
    end

    defp runtime_uploads(igniter) do
      case Install.configures?(igniter, "runtime.exs", :billboard, :uploads_dir) do
        {igniter, true} ->
          igniter

        {igniter, false} ->
          Igniter.Project.Config.configure_runtime_env(
            igniter,
            :prod,
            :billboard,
            [:uploads_dir],
            {:code,
             Sourceror.parse_string!("""
             System.get_env("UPLOADS_DIR") ||
               raise "environment variable UPLOADS_DIR is missing. Set it to a directory on a " <>
                       "volume that outlives a deploy: billboard keeps uploaded photographs there."
             """)},
            updater: &{:ok, &1}
          )
      end
    end

    # The site's tokens, billboard's theme and the editor's styles after
    # them, the files Tailwind reads, the editor's hooks, and the link
    # to billboard's assets, made before every build and kept out of git.
    defp assets(igniter) do
      igniter
      |> Install.create_file(
        "assets/css/billboard-tokens.css",
        Install.template("billboard.install", "billboard-tokens.css", %{})
      )
      |> Install.add_lines("assets/css/app.css", ~s|@import "tailwindcss"|, [
        ~s|@import "./billboard-tokens.css";|,
        ~s|@import "../vendor/billboard/assets/css/theme.css";|,
        ~s|@import "../vendor/billboard/assets/css/editor.css";|
      ])
      |> Install.add_lines("assets/css/app.css", {:last, "@source "}, Install.sources())
      |> Install.add_hooks()
      |> Install.add_line(".gitignore", "/assets/vendor/billboard")
      |> Install.add_line(".gitignore", "/priv/uploads/")
      |> Igniter.Project.TaskAliases.modify_existing_alias(
        "assets.build",
        &Install.after_compile(&1, "billboard.assets")
      )
      |> Igniter.Project.TaskAliases.modify_existing_alias(
        "assets.deploy",
        &Igniter.Code.List.prepend_new_to_list(&1, "billboard.assets")
      )
      |> Install.add_dev_server_alias()
    end

    defp notices(igniter, %{installed?: true} = names) do
      Igniter.add_notice(igniter, """
      Billboard is installed already, as #{inspect(names.site)}. This run adds only
      what's missing, and leaves the rest as it is: if it proposes no changes, the
      site has everything the installer writes. Billboard's getting started guide
      says what's next.
      """)
    end

    defp notices(igniter, _names) do
      Igniter.add_notice(igniter, """
      Billboard is installed. Write its tables' migrations, and run them:

          mix ash.codegen add_billboard
          mix ecto.migrate

      Then start the site, sign in, and open the editor. Billboard's
      getting started guide says what was written, and what's next.

      Every signed-in user can edit and publish every page, and
      `mix phx.gen.auth`'s /users/register lets anyone sign up. Before you
      deploy, close registration, or mount the editor in a live_session
      only your admins can join.
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
