defmodule Mix.Tasks.Billboard.InstallTest do
  @moduledoc "mix billboard.install: the config and the modules, written once."
  use ExUnit.Case, async: true

  import Igniter.Test
  import Billboard.Test.InstallProject

  defp install(igniter, argv \\ []), do: Igniter.compose_task(igniter, "billboard.install", argv)

  test "refuses a site without AshPostgres, and says how to set it up" do
    without_ash()
    |> install()
    |> assert_has_issue(fn issue ->
      issue =~ "MySite.Repo isn't an AshPostgres repo" and
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

  test "changes nothing the second time" do
    project()
    |> install()
    |> apply_igniter!()
    |> install()
    |> assert_unchanged()
  end
end
