defmodule Mix.Tasks.Billboard.InstallTest do
  @moduledoc "mix billboard.install: the config, the modules, and the web, written once."
  # Not async: while Igniter formats, it puts the test project's config,
  # `config :billboard, site: MySite.Billboard` among it, into the
  # application env, and two runs at once can leave it there for every
  # test after.
  use ExUnit.Case, async: false

  import Igniter.Test
  import Billboard.Test.InstallProject

  defp install(igniter, argv \\ []), do: Igniter.compose_task(igniter, "billboard.install", argv)

  # The text of `live_session NAME`'s block, from its line to its `end`,
  # so a route is asserted inside it and not merely somewhere after it.
  defp session_block(router, name) do
    lines = String.split(router, "\n")
    start = Enum.find_index(lines, &(&1 =~ ~r/live_session[ (]#{inspect(name)}\b/))
    assert start, "no live_session #{inspect(name)} in the router"
    [first | rest] = Enum.drop(lines, start)
    [indent] = Regex.run(~r/^\s*/, first)
    body = Enum.take_while(rest, &(&1 != indent <> "end"))
    Enum.join([first | body], "\n")
  end

  # The router with a live_session of the site's own, NAME, whose
  # on_mount is ON_MOUNT (or none), in a scope that pipes through only
  # :browser.
  defp with_session(name, on_mount) do
    opts = if on_mount, do: ", on_mount: #{on_mount}", else: ""

    project()
    |> content("lib/my_site_web/router.ex")
    |> String.replace("  ## Authentication routes", """
      scope "/admin", MySiteWeb do
        pipe_through :browser

        live_session #{inspect(name)}#{opts} do
          live "/", AdminLive
        end
      end

      ## Authentication routes\
    """)
  end

  test "refuses a site without AshPostgres, and says how to set it up" do
    without_ash()
    |> install()
    |> assert_has_issue(fn issue ->
      issue =~ "MySite has no AshPostgres repo" and
        issue =~ "mix igniter.install ash ash_postgres ash_phoenix"
    end)
  end

  test "configures billboard, its formatter, and its domain" do
    igniter = project() |> install()

    assert content(igniter, "config/config.exs") =~ "config :billboard"
    assert content(igniter, "config/config.exs") =~ "site: MySite.Billboard"
    assert content(igniter, "config/config.exs") =~ "ash_domains: [MySite.Pages]"
    assert content(igniter, ".formatter.exs") =~ ":billboard"
  end

  test "writes the site module, the modules billboard writes into, and the starter" do
    igniter = project() |> install()

    for path <- ~w(lib/my_site/billboard.ex lib/my_site/pages.ex lib/my_site/pages/page.ex
                   lib/my_site/pages/version.ex lib/my_site/pages/section.ex
                   lib/my_site/pages/content.ex lib/my_site/pages/starter.ex) do
      assert_creates(igniter, path)
    end

    site = content(igniter, "lib/my_site/billboard.ex")
    assert site =~ "use Billboard.Site"
    assert site =~ "otp_app: :my_site"
    assert site =~ "Billboard.Components.Hero"
    assert site =~ "layout: MySiteWeb.Layouts"

    assert content(igniter, "lib/my_site/pages.ex") =~
             "use Billboard.Domain, site: MySite.Billboard, extensions: [AshPhoenix]"

    assert content(igniter, "lib/my_site/pages/page.ex") =~
             "use Billboard.Page, site: MySite.Billboard"
  end

  test "names the site's AshPostgres repo, whatever it's called" do
    ecto_repo = """
    defmodule MySite.Repo do
      use Ecto.Repo, otp_app: :my_site, adapter: Ecto.Adapters.Postgres
    end
    """

    store = """
    defmodule MySite.Store do
      use AshPostgres.Repo, otp_app: :my_site
    end
    """

    site =
      project(%{"lib/my_site/repo.ex" => ecto_repo, "lib/my_site/store.ex" => store})
      |> install()
      |> content("lib/my_site/billboard.ex")

    assert site =~ "repo: MySite.Store"
  end

  test "writes no second site or domain for a site that has billboard under other names" do
    cms = """
    defmodule MySite.Cms do
      alias MySite.Content

      use Billboard.Site, otp_app: :my_site, repo: MySite.Repo, domain: Content
    end
    """

    config = project() |> content("config/config.exs")

    config =
      String.replace(
        config,
        "import Config\n",
        "import Config\n\nconfig :billboard, site: MySite.Cms\n"
      )

    igniter =
      project(%{"lib/my_site/cms.ex" => cms, "config/config.exs" => config})
      |> install(["--home"])

    refute_creates(igniter, "lib/my_site/billboard.ex")
    refute_creates(igniter, "lib/my_site/pages.ex")
    refute content(igniter, "config/config.exs") =~ "MySite.Pages"

    assert content(igniter, "lib/my_site_web/live/billboard_page_live.ex") =~
             "alias MySite.Content"

    assert_has_notice(igniter, &(&1 =~ "Billboard is installed already, as MySite.Cms"))
  end

  test "writes the site module a config names, when the site doesn't define it" do
    config =
      project()
      |> content("config/config.exs")
      |> String.replace(
        "import Config\n",
        "import Config\n\nconfig :billboard, site: MySite.Cms\n"
      )

    igniter = project(%{"config/config.exs" => config}) |> install()

    assert_has_warning(igniter, &(&1 =~ "names MySite.Cms, which the site doesn't define"))
    assert_creates(igniter, "lib/my_site/cms.ex")
    refute_creates(igniter, "lib/my_site/billboard.ex")
    assert content(igniter, "lib/my_site/cms.ex") =~ "defmodule MySite.Cms do"
  end

  test "starts the cache straight after PubSub" do
    children = project() |> install() |> content("lib/my_site/application.ex")
    assert children =~ ~r/\{Phoenix\.PubSub, name: MySite\.PubSub\},\s+Billboard\.Cache,/
  end

  test "leaves alone a module the site has already, wherever it lives" do
    igniter =
      project(%{"lib/my_site/billboard/site.ex" => "defmodule MySite.Billboard do\nend\n"})
      |> install()

    refute_creates(igniter, "lib/my_site/billboard.ex")
  end

  test "tells the site to write and run the migrations" do
    project()
    |> install()
    |> assert_has_notice(&(&1 =~ "mix ash.codegen add_billboard" and &1 =~ "mix ecto.migrate"))
  end

  test "warns that every signed-in user can publish, and anyone can sign up" do
    project()
    |> install()
    |> assert_has_notice(&(&1 =~ "/users/register lets anyone sign up" and &1 =~ "Before you"))
  end

  test "looks for the children only in start/2" do
    application = """
    defmodule MySite.Application do
      use Application

      @impl true
      def start(_type, _args) do
        Supervisor.start_link(children(), strategy: :one_for_one, name: MySite.Supervisor)
      end

      defp children do
        children = [{Phoenix.PubSub, name: MySite.PubSub}]
        children
      end
    end
    """

    project(%{"lib/my_site/application.ex" => application})
    |> install()
    |> assert_has_warning(&(&1 =~ "Couldn't find `{Phoenix.PubSub, …}`"))
    |> assert_unchanged("lib/my_site/application.ex")
  end

  test "says so when billboard is installed already, and still warns who can publish" do
    project()
    |> install()
    |> apply_igniter!()
    |> install()
    |> assert_has_notice(
      &(&1 =~ "Billboard is installed already, as MySite.Billboard" and
          &1 =~ "/users/register lets anyone sign up")
    )
  end

  test "names the file to move when one is where a module it writes belongs" do
    # Not applied: Igniter's test project would move the file to where
    # MySite.Elsewhere belongs.
    project()
    |> Igniter.create_new_file("lib/my_site/billboard.ex", "defmodule MySite.Elsewhere do\nend\n")
    |> install()
    |> assert_has_issue(
      &(&1 =~ "lib/my_site/billboard.ex is there already, and doesn't define MySite.Billboard")
    )
  end

  test "changes nothing the second time" do
    project()
    |> install()
    |> apply_igniter!()
    |> install()
    |> assert_unchanged()
  end

  describe "the web" do
    test "gives the site's Layouts a page layout for billboard" do
      layouts = project() |> install() |> content("lib/my_site_web/components/layouts.ex")

      assert layouts =~ "@behaviour Billboard.Layout"
      assert layouts =~ "def page(assigns)"
      assert layouts =~ ~s|<div class="bb-surface-band">{render_slot(@hero)}</div>|
    end

    test "leaves alone a Layouts that has a page/1" do
      layouts = """
      defmodule MySiteWeb.Layouts do
        use MySiteWeb, :html

        def page(assigns), do: ~H"<main>{render_slot(@inner_block)}</main>"
      end
      """

      project(%{"lib/my_site_web/components/layouts.ex" => layouts})
      |> install()
      |> assert_unchanged("lib/my_site_web/components/layouts.ex")
    end

    test "mounts the editor in the signed-in live_session, and imports its macro" do
      router = project() |> install() |> content("lib/my_site_web/router.ex")

      assert router =~ ~r/use MySiteWeb, :router\s+import Billboard\.Editor\.Router/

      assert session_block(router, :require_authenticated_user) =~
               ~r/billboard_editor[ (]"\/admin\/pages"/

      refute session_block(router, :current_user) =~ "billboard_editor"
    end

    test "won't mount the editor in :current_user, which is for everyone" do
      project()
      |> install(["--live-session", "current_user"])
      |> assert_has_warning(&(&1 =~ "`live_session :current_user`" and &1 =~ "for everyone"))
      |> content("lib/my_site_web/router.ex")
      |> then(&refute(&1 =~ "billboard_editor"))
    end

    test "won't mount the editor by default where only a scope's plug asks for signing in" do
      router =
        project()
        |> content("lib/my_site_web/router.ex")
        |> String.replace(
          "on_mount: [{MySiteWeb.UserAuth, :require_authenticated}]",
          "on_mount: [{MySiteWeb.UserAuth, :mount_current_scope}]"
        )

      project(%{"lib/my_site_web/router.ex" => router})
      |> install()
      |> assert_has_warning(
        &(&1 =~ "couldn't confirm `live_session :require_authenticated_user`" and
            &1 =~ "requires signing in")
      )
      |> content("lib/my_site_web/router.ex")
      |> then(&refute(&1 =~ "billboard_editor"))
    end

    test "mounts the editor in a session --live-session names whose on_mount requires a sign-in" do
      for on_mount <- ["[{MySiteWeb.UserAuth, :require_admin}]", "MySiteWeb.RequireAdmin"] do
        igniter =
          project(%{"lib/my_site_web/router.ex" => with_session(:admin, on_mount)})
          |> install(["--live-session", "admin"])

        assert session_block(content(igniter, "lib/my_site_web/router.ex"), :admin) =~
                 "billboard_editor"

        refute Enum.any?(igniter.notices, &(&1 =~ "couldn't confirm"))
      end
    end

    test "trusts a session --live-session names, and says it couldn't confirm it signs in" do
      igniter =
        project(%{"lib/my_site_web/router.ex" => with_session(:visitors, nil)})
        |> install(["--live-session", "visitors"])
        |> assert_has_notice(
          &(&1 =~ "`live_session :visitors`" and &1 =~ "couldn't confirm it requires signing in")
        )

      assert session_block(content(igniter, "lib/my_site_web/router.ex"), :visitors) =~
               "billboard_editor"
    end

    test "mounts the editor in a live_session of the site's whose on_mount signs in" do
      router =
        project()
        |> content("lib/my_site_web/router.ex")
        |> String.replace("  ## Authentication routes", """
          scope "/admin", MySiteWeb do
            pipe_through :browser

            live_session :admin, on_mount: [{MySiteWeb.UserAuth, :require_authenticated}] do
              live "/", AdminLive
            end
          end

          ## Authentication routes\
        """)

      router =
        project(%{"lib/my_site_web/router.ex" => router})
        |> install(["--live-session", "admin", "--editor-path", "/pages"])
        |> content("lib/my_site_web/router.ex")

      assert session_block(router, :admin) =~ ~r/billboard_editor[ (]"\/pages"/
    end

    test "takes another live_session and path" do
      router =
        project()
        |> install(["--live-session", "admin", "--editor-path", "/pages"])
        |> tap(&assert_has_warning(&1, fn w -> w =~ "Couldn't find `live_session :admin`" end))
        |> content("lib/my_site_web/router.ex")

      refute router =~ "billboard_editor"
    end

    test "with --home, draws the home page with billboard" do
      igniter = project() |> install(["--home"])

      assert_creates(igniter, "lib/my_site_web/live/billboard_page_live.ex")
      page_live = content(igniter, "lib/my_site_web/live/billboard_page_live.ex")
      assert page_live =~ "use MySiteWeb, :live_view"
      assert page_live =~ "site={@site}"
      assert page_live =~ "route_info(router, \"GET\", path, host)"

      router = content(igniter, "lib/my_site_web/router.ex")

      # In phx.gen.auth's :current_user session, whose on_mount gives
      # the root layout its @current_scope.
      assert session_block(router, :current_user) =~ ~r/live[ (]"\/", BillboardPageLive/
      refute session_block(router, :require_authenticated_user) =~ "BillboardPageLive"
      refute router =~ "PageController, :home"

      assert_has_notice(
        igniter,
        &(&1 =~ "test/my_site_web/controllers/page_controller_test.exs" and &1 =~ "fails")
      )
    end

    test "with --home, takes `/` for itself, not another scope's" do
      router =
        project()
        |> content("lib/my_site_web/router.ex")
        |> String.replace("  ## Authentication routes", """
          scope "/admin", MySiteWeb do
            pipe_through :browser

            live "/", AdminLive
          end

          ## Authentication routes\
        """)

      router =
        project(%{"lib/my_site_web/router.ex" => router})
        |> install(["--home"])
        |> content("lib/my_site_web/router.ex")

      assert session_block(router, :current_user) =~ ~r/live[ (]"\/", BillboardPageLive/
      refute router =~ "PageController, :home"
    end

    test "with --home, takes `/` for itself, not a keyword scope's" do
      router =
        project()
        |> content("lib/my_site_web/router.ex")
        |> String.replace("  ## Authentication routes", """
          scope path: "/admin", alias: MySiteWeb do
            pipe_through :browser

            live "/", AdminLive
          end

          ## Authentication routes\
        """)

      router =
        project(%{"lib/my_site_web/router.ex" => router})
        |> install(["--home"])
        |> content("lib/my_site_web/router.ex")

      assert session_block(router, :current_user) =~ ~r/live[ (]"\/", BillboardPageLive/
    end

    test "with --home, writes no page when `/` is routed already, and says so" do
      router =
        project()
        |> content("lib/my_site_web/router.ex")
        |> String.replace(~s|get "/", PageController, :home|, ~s|live "/", HomeLive|)

      igniter = project(%{"lib/my_site_web/router.ex" => router}) |> install(["--home"])

      refute_creates(igniter, "lib/my_site_web/live/billboard_page_live.ex")
      router = content(igniter, "lib/my_site_web/router.ex")
      assert router =~ ~s|live "/", HomeLive|
      refute router =~ "BillboardPageLive"
      assert_has_notice(igniter, &(&1 =~ "`/` is routed already, to HomeLive"))
    end

    test "the visitor page redraws only for a new version, and names the fix for a route with no page" do
      page_live =
        project() |> install(["--home"]) |> content("lib/my_site_web/live/billboard_page_live.ex")

      assert page_live =~ "Billboard.Snapshot.page(snapshot, pattern) || Pages.page_for(pattern)"
      assert page_live =~ "same_version?(socket.assigns.version, version)"
      assert page_live =~ "Billboard.Directory.fetch(pattern)"
      refute page_live =~ "fetch!("
      assert page_live =~ "has no billboard page"
      assert page_live =~ "takes parameters"
    end

    test "with --home, warns and leaves the router alone without :current_user" do
      router = project() |> content("lib/my_site_web/router.ex")
      router = String.replace(router, "live_session :current_user", "live_session :visitors")

      project(%{"lib/my_site_web/router.ex" => router})
      |> install(["--home"])
      |> tap(&assert_has_warning(&1, fn w -> w =~ ~s|live "/", BillboardPageLive| end))
      |> content("lib/my_site_web/router.ex")
      |> Kernel.=~("PageController, :home")
      |> assert()
    end

    test "without --home, writes no page of its own" do
      igniter = project() |> install()
      refute_creates(igniter, "lib/my_site_web/live/billboard_page_live.ex")
      assert content(igniter, "lib/my_site_web/router.ex") =~ "PageController, :home"
    end

    test "serves uploaded photographs, from a directory set for each environment" do
      igniter = project() |> install()

      assert content(igniter, "lib/my_site_web/endpoint.ex") =~
               ~r/plug[ (]Billboard\.Plugs\.UploadsStatic\)?\s+.*plug[ (]Plug\.Static/s

      assert content(igniter, "config/config.exs") =~
               ~s|uploads_dir: Path.expand("../priv/uploads", __DIR__)|

      assert content(igniter, "config/test.exs") =~
               ~s|uploads_dir: Path.expand("../tmp/test-uploads", __DIR__)|

      assert content(igniter, "config/runtime.exs") =~ "UPLOADS_DIR"
    end

    test "leaves alone a site and an uploads_dir set in config calls of their own" do
      config = project() |> content("config/config.exs")

      config =
        String.replace(
          config,
          "import Config\n",
          """
          import Config

          config :billboard, uploads_dir: Path.expand("../uploads", __DIR__)

          config :billboard, site: MySite.Billboard
          """
        )

      config =
        project(%{"config/config.exs" => config}) |> install() |> content("config/config.exs")

      assert [_] = Regex.scan(~r/uploads_dir:/, config)
      assert [_] = Regex.scan(~r/\bsite: MySite.Billboard/, config)
    end

    test "leaves a runtime uploads_dir alone wherever runtime.exs sets it" do
      # Outside the prod block, in a block of its own.
      runtime = """
      import Config

      uploads_dir = if config_env() != :test, do: System.get_env("UPLOADS_DIR")

      if uploads_dir do
        config :billboard, uploads_dir: uploads_dir
      end
      """

      project(%{"config/runtime.exs" => runtime})
      |> install()
      |> assert_unchanged("config/runtime.exs")
    end

    test "changes nothing the second time, --home and all" do
      project()
      |> install(["--home"])
      |> apply_igniter!()
      |> install(["--home"])
      |> assert_unchanged()
    end
  end

  describe "the assets" do
    test "writes the tokens file, and imports it, the theme, and the editor's styles" do
      igniter = project() |> install()

      assert_creates(igniter, "assets/css/billboard-tokens.css")
      css = content(igniter, "assets/css/app.css")

      imports = [
        ~s|@import "./billboard-tokens.css";|,
        ~s|@import "../vendor/billboard/assets/css/theme.css";|,
        ~s|@import "../vendor/billboard/assets/css/editor.css";|
      ]

      # Tailwind reads only where billboard draws classes, as
      # `mix billboard.assets`' moduledoc lists them, after the site's
      # last @source line (phx.new's colocated CSS).
      sources =
        for path <- ~w(sections sections.ex editor_live.ex editor_live editor),
            do: ~s|@source "../vendor/billboard/lib/billboard/#{path}";|

      assert css =~ ~r/@import "tailwindcss"[^\n]*\n#{Regex.escape(Enum.join(imports, "\n"))}\n/

      assert css =~
               ~s|@source "../../_build/dev/phoenix-colocated/my_site/*/";\n| <>
                 Enum.join(sources, "\n") <> "\n"

      refute css =~ ~s|@source "../vendor/billboard/lib";|
    end

    test "leaves alone the lines a site has already, among its own" do
      css = """
      @import "tailwindcss" source(none);
      @import "./my-palette.css";
      @import "./billboard-tokens.css";
      @import "../vendor/billboard/assets/css/theme.css";
      @import "../vendor/billboard/assets/css/editor.css";
      @source "../css";
      @source "../../lib/my_site_web";
      @source "../vendor/billboard/lib/billboard/sections";
      @source "../vendor/billboard/lib/billboard/sections.ex";
      @source "../vendor/billboard/lib/billboard/editor_live.ex";
      @source "../vendor/billboard/lib/billboard/editor_live";
      @source "../vendor/billboard/lib/billboard/editor";
      """

      js = """
      import {LiveSocket} from "phoenix_live_view"
      import {hooks as colocatedHooks} from "phoenix-colocated/my_site"
      import {hooks as billboardHooks} from "phoenix-colocated/billboard"
      import topbar from "../vendor/topbar"
      import {EditCanvas, InlineWords} from "../vendor/billboard/assets/js/billboard.js"
      import {Sortable} from "./sortable"

      const liveSocket = new LiveSocket("/live", Socket, {
        hooks: {...colocatedHooks, ...billboardHooks, EditCanvas, InlineWords, Sortable},
      })
      """

      project(%{
        "assets/css/app.css" => css,
        "assets/js/app.js" => js,
        "assets/css/billboard-tokens.css" => ":root {}\n",
        ".gitignore" => "/deps/\n/assets/vendor/billboard\n/priv/uploads/\n"
      })
      |> install()
      |> assert_unchanged(~w(assets/css/app.css assets/js/app.js
                             assets/css/billboard-tokens.css .gitignore))
    end

    test "leaves alone a tokens file the site has, though nothing has read it yet" do
      path = "assets/css/billboard-tokens.css"

      # Igniter's test project reads every file up front; a real one reads
      # a file only when asked, so forget this one, as a real run would.
      project(%{path => ":root {}\n"})
      |> Map.update!(:rewrite, fn rewrite ->
        %{rewrite | sources: Map.delete(rewrite.sources, path)}
      end)
      |> install()
      |> then(&refute Rewrite.has_source?(&1.rewrite, path))
    end

    test "gives the LiveSocket the editor's hooks" do
      js = project() |> install() |> content("assets/js/app.js")

      assert js =~
               ~s|import {hooks as colocatedHooks} from "phoenix-colocated/my_site"\n| <>
                 ~s|import {hooks as billboardHooks} from "phoenix-colocated/billboard"\n| <>
                 ~s|import {EditCanvas, InlineWords} from "../vendor/billboard/assets/js/billboard.js"\n|

      assert js =~ "hooks: {...colocatedHooks, ...billboardHooks, EditCanvas, InlineWords}"
    end

    test "says what to do when app.js names its hooks some other way" do
      odd =
        "import {Socket} from \"phoenix\"\nlet liveSocket = new LiveSocket(\"/live\", Socket, {})\n"

      project(%{"assets/js/app.js" => odd})
      |> install()
      |> assert_has_warning(&(&1 =~ "phoenix-colocated/billboard" and &1 =~ "EditCanvas"))
      |> assert_unchanged("assets/js/app.js")
    end

    test "keeps uploads out of a Docker image, when the site builds one" do
      igniter = project(%{".dockerignore" => "/deps/\n"}) |> install()
      assert content(igniter, ".dockerignore") == "/deps/\n/priv/uploads/\n"

      refute_creates(project() |> install(), ".dockerignore")
    end

    test "links billboard's assets before every build, and keeps the link and uploads out of git" do
      igniter = project() |> install()
      mix = content(igniter, "mix.exs")

      # After compile in the build, first in the deploy, as the README
      # has them.
      assert mix =~ ~r/"assets.build": \[\s*"compile",\s*"billboard.assets",/
      assert mix =~ ~r/"assets.deploy": \[\s*"billboard.assets",/
      assert content(igniter, ".gitignore") =~ "\n/assets/vendor/billboard\n"
      assert content(igniter, ".gitignore") =~ "\n/priv/uploads/\n"
    end

    test "leaves alone an assets.build that runs billboard.assets anywhere" do
      mix =
        project()
        |> content("mix.exs")
        |> String.replace(
          ~s|"assets.build": ["compile", |,
          ~s|"assets.build": ["billboard.assets", "compile", |
        )

      assert project(%{"mix.exs" => mix}) |> install() |> content("mix.exs") =~
               ~s|"assets.build": ["billboard.assets", "compile", "tailwind my_site", "esbuild my_site"]|
    end

    test "relinks billboard before the dev server's watchers read it" do
      mix = project() |> install() |> content("mix.exs")

      assert mix =~ "# In development, link billboard afresh"

      assert mix =~
               ~r/"phx.server":\s+if\(Mix.env\(\) == :dev, do: \["billboard.assets", "phx.server"\], else: \["phx.server"\]\)/
    end

    test "leaves alone a phx.server alias the site has" do
      mix =
        project()
        |> content("mix.exs")
        |> String.replace(
          ~s|precommit: [|,
          ~s|"phx.server": ["my_site.prepare", "phx.server"],\n      precommit: [|
        )

      project(%{"mix.exs" => mix})
      |> install()
      |> content("mix.exs")
      |> then(fn mix ->
        assert mix =~ ~s|"phx.server": ["my_site.prepare", "phx.server"]|
        refute mix =~ "link billboard afresh"
      end)
    end

    test "names the paths the README and mix billboard.assets give" do
      igniter = project() |> install()
      installed = content(igniter, "assets/css/app.css") <> content(igniter, "assets/js/app.js")
      readme = File.read!(Path.expand("../../../README.md", __DIR__))

      {:docs_v1, _, _, _, %{"en" => assets_doc}, _, _} =
        Code.fetch_docs(Mix.Tasks.Billboard.Assets)

      vendored = fn text ->
        ~r/^\s*(?:@import|@source|import) .*"\.\.\/vendor\/billboard\/[^"]+".*$/m
        |> Regex.scan(text)
        |> Enum.map(fn [line] -> String.trim(line) end)
        |> MapSet.new()
      end

      written = vendored.(installed)
      assert MapSet.subset?(MapSet.new(Billboard.Install.sources()), written)

      # Every billboard path the docs give, the installer writes, and the
      # reverse, so none can drift when billboard draws classes in a new
      # file.
      assert vendored.(readme) == written
      assert vendored.(assets_doc) == written

      for line <- written do
        [_, path] = Regex.run(~r/"\.\.\/vendor\/billboard\/([^"]+)"/, line)
        assert File.exists?(Path.expand("../../../" <> path, __DIR__)), "#{line} names no file"
      end
    end

    test "changes nothing the second time, the assets and all" do
      project()
      |> install()
      |> apply_igniter!()
      |> install()
      |> assert_unchanged(~w(assets/css/app.css assets/js/app.js assets/css/billboard-tokens.css
                             .gitignore mix.exs))
    end
  end
end
