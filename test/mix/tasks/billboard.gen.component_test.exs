defmodule Mix.Tasks.Billboard.Gen.ComponentTest do
  @moduledoc "mix billboard.gen.component: a component that works as written, listed in the site."
  # Not async: while Igniter formats, it puts the test project's config,
  # `config :billboard, site: MySite.Billboard` among it, into the
  # application env, and two runs at once can leave it there for every
  # test after.
  use ExUnit.Case, async: false

  import Igniter.Test
  import Billboard.Test.InstallProject

  defp installed,
    do: project() |> Igniter.compose_task("billboard.install", []) |> apply_igniter!()

  defp gen(igniter, argv), do: Igniter.compose_task(igniter, "billboard.gen.component", argv)

  test "writes the data module, the renderer, and the test, and lists the component" do
    igniter = installed() |> gen(["MySite.Sections.Faq"])

    assert_creates(igniter, "lib/my_site/sections/faq.ex")
    assert_creates(igniter, "lib/my_site_web/sections/faq.ex")
    assert_creates(igniter, "test/my_site/sections/faq_test.exs")
    refute_creates(igniter, "lib/my_site/sections/faq/question.ex")

    component = content(igniter, "lib/my_site/sections/faq.ex")
    assert component =~ "key(:faq)" or component =~ "key :faq"

    assert component =~ "renderer(MySiteWeb.Sections.Faq)" or
             component =~ "renderer MySiteWeb.Sections.Faq"

    assert content(igniter, "test/my_site/sections/faq_test.exs") =~
             "use Billboard.ComponentCase, endpoint: MySiteWeb.Endpoint, repo: MySite.Repo"

    assert content(igniter, "lib/my_site/billboard.ex") =~
             ~r/Billboard\.Components\.Shared,\s+MySite\.Sections\.Faq\s*\]/
  end

  test "with --list, writes the part its list holds" do
    igniter = installed() |> gen(["MySite.Sections.Faq", "--list", "question"])

    assert_creates(igniter, "lib/my_site/sections/faq/question.ex")
    assert content(igniter, "lib/my_site/sections/faq/question.ex") =~ "use Billboard.Part"
    assert content(igniter, "lib/my_site/sections/faq.ex") =~ ":questions"
    assert content(igniter, "lib/my_site_web/sections/faq.ex") =~ ~S|"questions.#{|
  end

  test "takes a key and a renderer of its own" do
    igniter =
      installed()
      |> gen(["MySite.Sections.Faq", "--key", "questions", "--renderer", "MySiteWeb.Questions"])

    assert content(igniter, "lib/my_site/sections/faq.ex") =~ "questions"
    assert_creates(igniter, "lib/my_site_web/questions.ex")
    assert content(igniter, "lib/my_site_web/questions.ex") =~ "defmodule MySiteWeb.Questions"
  end

  test "lists the component in the site module --site names" do
    site = """
    defmodule MySite.Pages.Site do
      use Billboard.Site,
        otp_app: :my_site,
        components: [Billboard.Components.Hero]
    end
    """

    igniter =
      project(%{"lib/my_site/pages/site.ex" => site})
      |> gen(["MySite.Sections.Faq", "--site", "MySite.Pages.Site"])

    assert content(igniter, "lib/my_site/pages/site.ex") =~
             ~r/Billboard\.Components\.Hero,\s+MySite\.Sections\.Faq\s*\]/
  end

  test "says what to add when there's no site module to list it in" do
    project()
    |> gen(["MySite.Sections.Faq"])
    |> assert_has_warning(&(&1 =~ "Add MySite.Sections.Faq to `components:`"))
  end

  test "refuses a key that isn't a plain name" do
    installed()
    |> gen(["MySite.Sections.Faq", "--key", "Not a key"])
    |> assert_has_issue(&(&1 =~ "`--key` names the key content is stored under"))
  end

  test "refuses a list that isn't a plain name" do
    installed()
    |> gen(["MySite.Sections.Faq", "--list", "Big question"])
    |> assert_has_issue(&(&1 =~ "`--list` names one item of the list"))
  end

  test "needs a renderer for a module outside the site's own" do
    installed()
    |> gen(["Elsewhere.Faq"])
    |> assert_has_issue(&(&1 =~ "Elsewhere.Faq isn't under MySite" and &1 =~ "--renderer"))
  end

  test "refuses a module the site has that isn't a component, and writes nothing" do
    accounts = """
    defmodule MySite.Accounts do
      @moduledoc false
    end
    """

    installed()
    |> Igniter.create_new_file("lib/my_site/accounts.ex", accounts)
    |> apply_igniter!()
    |> gen(["MySite.Accounts"])
    |> assert_has_issue(
      &(&1 =~ "MySite.Accounts is in the site already" and &1 =~ "another name")
    )
    |> refute_creates("lib/my_site_web/accounts.ex")
    |> assert_unchanged("lib/my_site/billboard.ex")
  end

  test "leaves alone a component the site has, though nothing has read it yet, and says so" do
    path = "lib/my_site/sections/faq.ex"
    first = installed() |> gen(["MySite.Sections.Faq"]) |> apply_igniter!()

    mine = """
    defmodule MySite.Sections.Faq do
      @moduledoc "The site's own, changed since it was generated."
      use Billboard.Component
    end
    """

    # Igniter's test project reads every file up front; a real one reads
    # a file only when asked, so forget this one, as a real run would.
    first
    |> Igniter.update_file(path, &Rewrite.Source.update(&1, :content, mine))
    |> apply_igniter!()
    |> Map.update!(:rewrite, &%{&1 | sources: Map.delete(&1.sources, path)})
    |> gen(["MySite.Sections.Faq"])
    |> assert_has_notice(&(&1 =~ "MySite.Sections.Faq is in the site already"))
    |> then(fn igniter ->
      refute Igniter.changed?(igniter, path)
    end)
  end

  test "changes nothing the second time" do
    installed()
    |> gen(["MySite.Sections.Faq", "--list", "question"])
    |> apply_igniter!()
    |> gen(["MySite.Sections.Faq", "--list", "question"])
    |> assert_unchanged()
  end
end
