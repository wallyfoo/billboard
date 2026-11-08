defmodule Billboard.EditorLive.RetiredTest do
  @moduledoc """
  The page editor on a page holding a section of a component the site no
  longer has: a stand-in naming its key, which opens to a header that
  offers Remove, and an issue that holds Publish back until it's gone.
  """
  use Billboard.Test.LiveCase, async: false

  alias Billboard.{Editor, Pages}
  alias Billboard.Test.{Router, Shop}

  @opts [authorize?: false]

  # Each refresh of the cache warns of the leaflet while it's live.
  @moduletag :capture_log

  setup :preserve_cache

  setup do
    {:ok, live} =
      Shop.Pages.put_page(
        "/about",
        [%{type: :hero, content: %{heading: "About us"}}, %{type: :text, content: %{body: "Hi"}}],
        @opts
      )

    key =
      stored_section_fixture(live, :leaflet, %{"title" => "Old leaflet"}, position: 2)

    Billboard.Cache.refresh()
    %{key: key}
  end

  defp editor(pattern) do
    {:ok, lv, _html} = live(signed_in(build_conn()), Editor.path(Router, pattern, []))
    lv
  end

  defp draft_types do
    {:ok, draft} = Pages.draft_for("/about", @opts)
    Enum.map(draft.sections, & &1.content.type)
  end

  test "draws a stand-in naming the component the site no longer has", %{key: key} do
    lv = editor("/about")

    assert has_element?(lv, "#edit-#{key}[data-retired='leaflet']")
    assert has_element?(lv, "#edit-#{key} .bb-edit-stand-in", "“leaflet”")
    assert has_element?(lv, "#open-#{key}", "Retired component “leaflet”")
    refute has_element?(lv, "#edit-#{key}", "Old leaflet")
  end

  test "marks it as an error, and holds Publish back while a draft holds it", %{key: key} do
    {:ok, _draft} = Shop.Pages.edit_page("/about", @opts)
    lv = editor("/about")

    assert has_element?(lv, "#edit-#{key}[data-issue='error']")
    assert has_element?(lv, "#commit-changes[disabled][aria-describedby='commit-blockers']")
  end

  test "opens to a header that says why, and removes it, after asking", %{key: key} do
    lv = editor("/about")
    render_click(lv, "open_section", %{"key" => key})

    assert has_element?(lv, "#edit-#{key} #section-editor[data-section='#{key}']")
    assert has_element?(lv, "#section-retired", "“leaflet”")
    assert has_element?(lv, "#section-issues", "is no longer on the site")
    refute has_element?(lv, "#section-settings")

    assert has_element?(lv, "#section-remove[data-confirm]")
    lv |> element("#section-remove") |> render_click()

    assert draft_types() == [:hero, :text]
    refute has_element?(lv, "#edit-#{key}")

    lv |> element("#commit-changes") |> render_click()
    assert Enum.map(Pages.page_for("/about").sections, & &1.content.type) == [:hero, :text]
  end

  test "ignores what a forged event sends it", %{key: key} do
    lv = editor("/about")
    render_click(lv, "open_section", %{"key" => key})

    lv
    |> with_target("#section-editor")
    |> render_hook("edit_words", %{"path" => "title", "text" => "New"})

    assert {:ok, nil} = Pages.draft_for("/about", @opts)
  end

  test "moves it, as any section", %{key: key} do
    lv = editor("/about")
    render_click(lv, "open_section", %{"key" => key})
    lv |> element("#section-move-up") |> render_click()

    assert draft_types() == [:hero, :retired, :text]
  end
end
