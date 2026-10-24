defmodule Mix.Tasks.Billboard.InstallTest do
  @moduledoc "mix billboard.install: the config, the modules, and the web, written once."
  use ExUnit.Case, async: true

  import Igniter.Test
  import Billboard.Test.InstallProject

  defp install(igniter, argv \\ []), do: Igniter.compose_task(igniter, "billboard.install", argv)

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

  test "says so when billboard is installed already" do
    project()
    |> install()
    |> apply_igniter!()
    |> install()
    |> assert_has_notice(&(&1 =~ "Billboard is installed already, as MySite.Billboard"))
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

      assert router =~
               ~r/live_session[ (]:require_authenticated_user.*billboard_editor[ (]"\/admin\/pages"/s
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
      assert page_live =~ "route_info(socket.router, \"GET\", path, host)"

      router = content(igniter, "lib/my_site_web/router.ex")

      # In phx.gen.auth's :current_user session, whose on_mount gives
      # the root layout its @current_scope.
      assert router =~ ~r/live_session[ (]:current_user.*live[ (]"\/", BillboardPageLive/s
      refute router =~ "PageController, :home"
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

      assert router =~ ~r/live_session[ (]:current_user.*live[ (]"\/", BillboardPageLive/s
      refute router =~ "PageController, :home"
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
end
