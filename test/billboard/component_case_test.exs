defmodule Billboard.ComponentCaseTest do
  @moduledoc "assert_component_works/2 passes a component that works, and names the fix for one that doesn't."
  use Billboard.ComponentCase,
    endpoint: Billboard.Test.Endpoint,
    repo: Billboard.Test.Repo,
    async: false

  import Billboard.Test.Env

  alias Billboard.ComponentCase
  alias Billboard.Test.Broken

  test "passes the guides' FAQ" do
    assert_component_works(MySite.Sections.Faq)
  end

  test "names a placeholder that doesn't pass the component's validations" do
    put_site!(components: [Broken.Unbuildable])

    error =
      assert_raise ExUnit.AssertionError, fn ->
        ComponentCase.check_placeholder(Broken.Unbuildable)
      end

    assert error.message =~ "Broken.Unbuildable's placeholder doesn't build: add a title."
    assert error.message =~ "Change `placeholder` in its `component` section"
  end

  test "names a list whose added item doesn't build" do
    put_site!(components: [Broken.Mislisted])

    error =
      assert_raise ExUnit.AssertionError, fn -> ComponentCase.check_items(Broken.Mislisted) end

    assert error.message =~ "an item added to `items` starts as the blank of :detail"
    assert error.message =~ "Name the part the list holds in its `editor` entry"
  end

  test "names a glyph that draws nothing" do
    put_site!(components: [Broken.Glyphless])

    error =
      assert_raise ExUnit.AssertionError, fn -> ComponentCase.check_glyph(Broken.Glyphless) end

    assert error.message =~ "Broken.Glyphless's glyph draws nothing"
  end

  test "names words the open section doesn't type in place" do
    error =
      assert_raise ExUnit.AssertionError, fn ->
        ComponentCase.check_open(@endpoint, Billboard.Test.Unwritten, page: "/")
      end

    assert error.message =~ "names `note` as words in its `editor`, but the open section"
    assert error.message =~ ~s|Words.text(@ctx, "note", @content.note)|
    refute error.message =~ "`title`"
  end

  test "checks the open section's words and fields each on its own" do
    assert_raise ExUnit.AssertionError, ~r/`note`/, fn ->
      ComponentCase.check_words(@endpoint, Billboard.Test.Unwritten, page: "/")
    end

    assert ComponentCase.check_fields(@endpoint, Billboard.Test.Unwritten, page: "/") == :ok
    assert ComponentCase.check_fields(@endpoint, MySite.Sections.Faq) == :ok
  end

  test "names a component no page may take, and how to widen its kinds" do
    error =
      assert_raise ExUnit.AssertionError, fn ->
        ComponentCase.check_listed(Billboard.Test.Unwritten)
      end

    assert error.message =~
             "no page the site lists may take Billboard.Test.Unwritten: its kinds are []"

    assert error.message =~ "widen `kinds:` in `use Billboard.Site`"
  end

  test "refuses a module that isn't a component, and says what to add" do
    error = assert_raise ExUnit.AssertionError, fn -> assert_component_works(String) end

    assert error.message =~
             "String isn't a billboard component. Give it `use Billboard.Component`"
  end
end
