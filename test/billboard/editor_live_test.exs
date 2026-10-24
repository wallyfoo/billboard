defmodule Billboard.EditorLiveTest do
  # Makes and changes drafts, and puts pages live in the shared cache,
  # which other tests read.
  use Billboard.Test.LiveCase, async: false

  import Billboard.Test.ShopPages

  alias Billboard.{Editor, Pages, Sections}
  alias Billboard.Test.{GroundRule, Router, Shop}

  @opts [authorize?: false]

  setup :preserve_cache

  # The editor's address for a page, as its links make it.
  defp address(pattern, opts \\ []), do: Editor.path(Router, pattern, opts)

  defp editor(pattern, opts \\ []) do
    {:ok, lv, _html} = live(signed_in(build_conn()), address(pattern, opts))
    lv
  end

  defp keys(pattern), do: Enum.map(Pages.page_for(pattern).sections, & &1.key)

  defp draft(pattern) do
    {:ok, draft} = Pages.draft_for(pattern, @opts)
    draft
  end

  defp no_draft?(pattern), do: Pages.draft_for(pattern, @opts) == {:ok, nil}

  defp draft_types(pattern), do: Enum.map(draft(pattern).sections, & &1.content.type)
  defp types(pattern), do: Enum.map(Pages.page_for(pattern).sections, & &1.content.type)

  defp section_of(pattern, type),
    do: Enum.find(Pages.page_for(pattern).sections, &(&1.content.type == type))

  # Adds a section from the palette, at the gap `at`, or at the end.
  defp add(lv, component, at \\ nil) do
    palette(lv, at)
    lv |> element("#section-palette button[phx-value-component='#{component}']") |> render_click()
  end

  # Opens the palette at the gap `at`, or the last one, at the end.
  defp palette(lv, at \\ nil) do
    gap = if at, do: "section-add-at-#{at}", else: last_gap(lv)
    lv |> element("##{gap}") |> render_click()
  end

  defp last_gap(lv) do
    lv
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("[id^='section-add-at-']")
    |> LazyHTML.attribute("id")
    |> List.last()
  end

  defp open(lv, key), do: render_click(lv, "open_section", %{"key" => key})

  # Where the editor draws a section: the hero on its own `<section>`,
  # and every other section in its wrapper.
  defp drawn?(lv, key),
    do:
      has_element?(lv, "#edit-#{key}") or
        has_element?(lv, "#page-hero[data-edit-section='#{key}']")

  # Sent to the open section's editor, as the words' hook sends it.
  defp edit_words(lv, path, text) do
    lv
    |> with_target("#section-editor")
    |> render_hook("edit_words", %{"path" => path, "text" => text})

    # The editor's save reaches the page editor after the reply.
    render(lv)
  end

  test "redirects a visitor away" do
    assert {:error, {:redirect, %{to: "/"}}} = live(build_conn(), address("/"))
  end

  describe "signed in" do
    setup do: about!()

    test "lists every page, with the shared library last, and opens on Home" do
      lv = editor("/")

      assert has_element?(lv, "#page-list a[aria-current='page']", "Home")
      assert has_element?(lv, "#page-picker-toggle", "Home")
      assert has_element?(lv, "#page-list a[href='/pages?page=%2Fabout']", "About")
      assert has_element?(lv, "#page-list li:last-child", "Shared sections")
    end

    test "goes back to the admin from its bar, as its route says" do
      lv = editor("/")

      assert has_element?(lv, "#editor-back[href='/admin']", "Admin")
    end

    test "an unknown page opens Home" do
      lv = editor("/nowhere")
      assert has_element?(lv, "#page-list a[aria-current='page']", "Home")
    end

    test "opens the shared library, which has no hero" do
      lv = editor(nil)

      assert has_element?(lv, "#page-list a[aria-current='page']", "Shared sections")
      refute has_element?(lv, "#page-hero[data-edit-section]")

      for key <- keys(nil), do: assert(has_element?(lv, "main > #edit-#{key}"))

      palette(lv)
      refute has_element?(lv, "#section-palette button[phx-value-component='shared']")
      refute has_element?(lv, "#section-palette button[phx-value-component='columns']")
    end

    test "opens a section of the library" do
      [key | _] = keys(nil)
      lv = editor(nil)

      open(lv, key)
      assert has_element?(lv, "#edit-#{key} #section-editor[data-section='#{key}']")
    end

    test "patches between pages" do
      lv = editor("/")

      lv |> element("#page-list a", "About") |> render_click()

      assert_patch(lv, "/pages?page=%2Fabout")
      assert has_element?(lv, "#page-list a[aria-current='page']", "About")

      for key <- keys("/about"), do: assert(drawn?(lv, key))
    end

    test "draws the live page's sections, by key, without making a draft" do
      lv = editor("/about")

      for key <- keys("/about"), do: assert(drawn?(lv, key))

      assert no_draft?("/about")
    end

    test "the first change makes the draft, and the live page doesn't change" do
      lv = editor("/about")

      add(lv, "text_media")

      assert List.last(draft_types("/about")) == :text_media
      refute :text_media in types("/about")
      assert has_element?(lv, "#page-list a[data-draft]", "About")
      assert has_element?(lv, "#page-picker-toggle .bg-bb-edit-warn")
    end

    test "adds a section at the end, and removes it" do
      lv = editor("/about")
      add(lv, "text_media")

      new = List.last(draft("/about").sections)
      assert has_element?(lv, "main > #edit-#{new.key} + .bb-edit-gap:last-child")

      render_click(lv, "remove_section", %{"key" => new.key})
      refute has_element?(lv, "#edit-#{new.key}")
      refute :text_media in draft_types("/about")
    end

    test "removing the open section closes it, without blaming anyone else" do
      lv = editor("/about")
      add(lv, "text_media")
      new = List.last(draft("/about").sections)
      open(lv, new.key)

      render_click(lv, "remove_section", %{"key" => new.key})

      refute has_element?(lv, "#section-editor")
      refute has_element?(lv, "#flash-info", "Someone else")
    end

    test "every component the palette offers adds a valid section" do
      lv = editor("/")

      for component <- ~w(band cards text points text_media details reviews news columns shared) do
        add(lv, component)
        refute has_element?(lv, "#flash-error")
      end

      assert draft_types("/") ==
               [:hero, :text] ++
                 ~w(band cards text points text_media details reviews news columns shared)a
    end

    test "two columns arrive holding two sections, each opened on its own" do
      lv = editor("/")
      add(lv, "columns")

      columns = List.last(draft("/").sections)
      assert [left, _right] = columns.children

      for child <- columns.children,
          do: assert(has_element?(lv, "#edit-#{columns.key} #edit-#{child.key}"))

      open(lv, left.key)
      assert has_element?(lv, "#edit-#{left.key} #section-editor[data-section='#{left.key}']")
    end

    test "a shared section points at a library section the page doesn't have yet" do
      lv = editor("/")
      add(lv, "shared")

      shared = List.last(draft("/").sections)
      assert Map.has_key?(Pages.shared_sections(), shared.content.value.key)

      # The library holds one section, now placed, so there is nothing more to share.
      palette(lv)

      assert has_element?(
               lv,
               "#section-palette button[phx-value-component='shared'][aria-disabled='true']"
             )
    end

    test "a shared section draws its library section as visitors see it" do
      shared = section_of("/about", :shared)
      source = Pages.shared_sections()[shared.content.value.key]
      lv = editor("/about")

      assert has_element?(lv, "#edit-#{shared.key} ##{Sections.anchor(source)}")
      refute has_element?(lv, "#edit-#{shared.key} [data-edit-section]")

      open(lv, shared.key)
      refute has_element?(lv, "#edit-#{shared.key} [contenteditable]")
    end

    test "moves a section down" do
      [_hero, second, third | _] = keys("/about")
      lv = editor("/about")

      render_click(lv, "move", %{"key" => second, "dir" => "down"})

      assert [_, ^third, ^second | _] = Enum.map(draft("/about").sections, & &1.key)
      assert has_element?(lv, "main > #section-gap-1:first-child + #edit-#{third}")
    end

    test "nothing moves above the hero" do
      [_hero, second | _] = keys("/about")
      lv = editor("/about")

      render_click(lv, "move", %{"key" => second, "dir" => "up"})

      refute has_element?(lv, "#flash-error")
      assert no_draft?("/about")
    end

    test "a fixed page has no places to add a section" do
      lv = editor("/terms")
      refute has_element?(lv, ".bb-edit-gap")
      refute has_element?(lv, "[id^='section-add-at-']")
    end

    test "only offers components the page can use" do
      lv = editor("/about")
      palette(lv)
      assert has_element?(lv, "#section-palette button[phx-value-component='text_media']")

      assert has_element?(
               lv,
               "#section-palette button[phx-value-component='news'][aria-disabled='true']"
             )

      # An item page's kind takes no Two columns.
      item!()
      lv = editor("/items/:slug")
      palette(lv)
      assert has_element?(lv, "#section-palette button[phx-value-component='text_media']")
      refute has_element?(lv, "#section-palette button[phx-value-component='columns']")
    end

    test "turns down a component the page can't use" do
      item!()
      lv = editor("/items/:slug")

      render_click(lv, "add_section", %{"component" => "columns"})

      assert no_draft?("/items/:slug")
      assert has_element?(lv, "#flash-error", "can't go on this page")
    end

    test "doesn't remove the hero, which its header doesn't offer to" do
      hero = hd(keys("/about"))
      lv = editor("/about")

      render_click(lv, "remove_section", %{"key" => hero})

      assert no_draft?("/about")
      refute has_element?(lv, "#flash-error")
      refute has_element?(lv, "#page-list a[data-draft]")
    end

    test "a refused first change, to a section that has gone, says so and makes no draft" do
      lv = editor("/about")

      render_click(lv, "remove_section", %{"key" => "not-a-section"})

      assert has_element?(lv, "#flash-error", "That section has gone")
      assert no_draft?("/about")
      refute has_element?(lv, "#page-list a[data-draft]")
    end

    test "a refused later change keeps the draft as it was" do
      lv = editor("/about")
      add(lv, "text_media")
      before = Enum.map(draft("/about").sections, & &1.key)

      render_click(lv, "remove_section", %{"key" => "not-a-section"})

      assert Enum.map(draft("/about").sections, & &1.key) == before
      assert has_element?(lv, "#flash-error", "That section has gone")
      assert has_element?(lv, "#page-list a[data-draft]", "About")
    end

    test "viewing as a visitor, nothing is removed, moved, or swapped" do
      lv = editor("/about")
      lv |> element("#mode-view") |> render_click()

      render_click(lv, "remove_section", %{"key" => "story"})
      render_click(lv, "move", %{"key" => "story", "dir" => "up"})
      render_click(lv, "swap_columns", %{"key" => section_of("/about", :columns).key})

      assert no_draft?("/about")
    end

    test "a fixed page's sections and a column's section aren't removed or moved" do
      lv = editor("/terms")

      render_click(lv, "remove_section", %{"key" => "terms"})
      render_click(lv, "move", %{"key" => "terms", "dir" => "up"})

      assert no_draft?("/terms")
      refute has_element?(lv, "#flash-error")

      [left, _right] = section_of("/about", :columns).children
      lv = editor("/about")

      render_click(lv, "remove_section", %{"key" => left.key})
      render_click(lv, "move", %{"key" => left.key, "dir" => "down"})

      assert no_draft?("/about")
      refute has_element?(lv, "#flash-error")
    end

    test "each section's label names its component" do
      lv = editor("/about")
      [hero, points | _] = Pages.page_for("/about").sections

      assert has_element?(lv, "#page-hero #open-#{hero.key}", "Hero · Click to edit")

      assert has_element?(
               lv,
               "#edit-#{points.key} > #open-#{points.key}",
               "Points · Click to edit"
             )
    end

    test "palette buttons and page tabs have ids" do
      lv = editor("/about")
      palette(lv)

      assert has_element?(
               lv,
               "#section-palette #section-palette-text_media[phx-value-component='text_media']"
             )

      assert has_element?(lv, "#page-tab-home", "Home")
      assert has_element?(lv, "#page-tab-about[aria-current='page']")
      assert has_element?(lv, "#page-tab-items-slug", "An item")
      assert has_element?(lv, "#page-tab-shared", "Shared sections")
    end
  end

  describe "the page" do
    setup do: about!()

    test "is the site's own, under the editor's bar" do
      lv = editor("/about")

      assert has_element?(lv, "#editor-bar")
      assert has_element?(lv, "#edit-canvas #shop-header")
      assert has_element?(lv, "#edit-canvas #page-hero h1")
      assert has_element?(lv, "#edit-canvas #shop-footer")
    end

    test "keeps its bar on top, and tells the layout the address drawn and that it's editing" do
      lv = editor("/about")

      assert has_element?(lv, "#editor-bar.sticky")
      assert has_element?(lv, "#shop-header[data-path='/about']")

      add(lv, "text_media")
      lv |> element("#commit-changes") |> render_click()

      # The editor draws the message; the layout, editing, draws none.
      assert has_element?(lv, "#flash-info", "Published.")
      refute has_element?(lv, "#shop-flash")
    end

    test "opening a section draws its editor inside it, and in no other" do
      [_hero, first, second | _] = keys("/about")
      lv = editor("/about")
      refute has_element?(lv, "#section-editor")

      lv |> element("#open-#{first}") |> render_click()

      assert has_element?(
               lv,
               "#edit-#{first}[data-open='true'] #section-editor[data-section='#{first}']"
             )

      assert has_element?(lv, "#edit-#{first} [contenteditable]")
      assert has_element?(lv, "#edit-canvas[data-has-open]")
      refute has_element?(lv, "#edit-#{second} #section-editor")
      refute has_element?(lv, "#edit-#{second} [contenteditable]")

      open(lv, second)
      assert has_element?(lv, "#edit-#{second} #section-editor")
      refute has_element?(lv, "#edit-#{first} #section-editor")
      refute has_element?(lv, "#edit-#{first} [contenteditable]")
    end

    test "a closed section opens on a click anywhere in it" do
      [_hero, first | _] = keys("/about")
      lv = editor("/about")

      lv |> element("#edit-#{first}") |> render_click()

      assert has_element?(lv, "#edit-#{first} #section-editor")
      refute has_element?(lv, "#edit-#{first}[phx-click]")
    end

    test "opens the hero in the header block" do
      hero = hd(keys("/about"))
      lv = editor("/about")

      lv |> element("#page-hero") |> render_click()

      assert has_element?(
               lv,
               "#page-hero[data-open='true'] #section-editor[data-section='#{hero}']"
             )

      assert has_element?(lv, "#page-hero h1 [contenteditable][data-path='heading']")
    end

    test "a key that isn't one of the page's opens nothing" do
      lv = editor("/about")

      open(lv, "not-a-section")
      # A section of another page.
      open(lv, "welcome")

      refute has_element?(lv, "#section-editor")
    end

    test "Done closes the open section" do
      [_hero, first | _] = keys("/about")
      lv = editor("/about")
      open(lv, first)

      lv |> element("#section-done") |> render_click()

      refute has_element?(lv, "#section-editor")
      refute has_element?(lv, "[contenteditable]")
      refute has_element?(lv, "#edit-canvas[data-has-open]")
    end

    test "the address can open a section" do
      [_hero, first | _] = keys("/about")
      lv = editor("/about", open: first)

      assert has_element?(lv, "#edit-#{first} #section-editor")
    end

    test "closing the section the address opened takes it out of the address" do
      [_hero, first | _] = keys("/about")
      lv = editor("/about", open: first)

      lv |> element("#section-done") |> render_click()

      assert_patch(lv, "/pages?page=%2Fabout")
      refute has_element?(lv, "#section-editor")
    end

    test "the address opens nothing while viewing as a visitor" do
      [_hero, first | _] = keys("/about")
      lv = editor("/about")
      lv |> element("#mode-view") |> render_click()

      render_patch(lv, address("/about", open: first))

      refute has_element?(lv, "#section-editor")
    end

    test "a column opens on its own, inside a closed Two columns" do
      cols = section_of("/about", :columns)
      [left, _right] = cols.children
      lv = editor("/about")

      lv |> element("#edit-#{left.key}") |> render_click()

      assert has_element?(lv, "#edit-#{left.key} #section-editor[data-section='#{left.key}']")
      assert has_element?(lv, "#edit-#{cols.key}[data-open='false']")
      # A click in the open column isn't the pair's.
      refute has_element?(lv, "#edit-#{cols.key}[phx-click]")
    end

    test "a section stays open while another admin changes the page" do
      [_hero, first | _] = keys("/about")
      lv = editor("/about")
      open(lv, first)

      {:ok, _draft} = Shop.Pages.edit_page("/about", @opts)

      assert has_element?(lv, "#discard-changes:not([disabled])")
      assert has_element?(lv, "#edit-#{first} #section-editor")
      refute has_element?(lv, "#flash-info")
    end

    test "another page closes the open section" do
      [_hero, first | _] = keys("/about")
      lv = editor("/about", open: first)

      lv |> element("#page-list a", "Home") |> render_click()

      refute has_element?(lv, "#section-editor")
      refute has_element?(lv, "#flash-info")
    end

    test "viewing as a visitor draws none of the editor's marks" do
      [_hero, first | _] = keys("/about")
      lv = editor("/about", open: first)

      lv |> element("#mode-view") |> render_click()

      assert has_element?(lv, "#mode-view[aria-pressed='true']")
      refute has_element?(lv, "[data-edit-section]")
      refute has_element?(lv, "[contenteditable]")
      refute has_element?(lv, "#section-editor")
      refute has_element?(lv, ".bb-edit-gap")
      assert has_element?(lv, "#edit-canvas #page-hero h1")

      open(lv, first)
      refute has_element?(lv, "#section-editor")

      lv |> element("#mode-edit") |> render_click()
      assert has_element?(lv, "#edit-#{first}[data-edit-section]")
    end

    test "words typed in place save to the draft, and the bar offers to publish them" do
      hero = hd(keys("/about"))
      lv = editor("/about")
      open(lv, hero)

      edit_words(lv, "heading", "A *new* shop")

      assert draft("/about").sections
             |> hd()
             |> Map.get(:content)
             |> Map.get(:value)
             |> Map.get(:heading) ==
               "A *new* shop"

      assert has_element?(lv, "#draft-status", "Your changes aren't on the site yet.")
      assert has_element?(lv, "#commit-changes:not([disabled])")
      assert has_element?(lv, "#page-hero h1 [data-words='A *new* shop']")
      assert has_element?(lv, "#page-hero #section-editor")
    end

    test "the field being typed in keeps its id through a save" do
      field = "#words-story-points-0-title"
      lv = editor("/about")
      open(lv, "story")
      assert has_element?(lv, field)

      edit_words(lv, "points.0.title", "Founded, told again")

      assert has_element?(lv, "#{field}[data-words='Founded, told again']")
    end

    test "a page whose route has a parameter is drawn with the site's sample, at its address" do
      item!()
      lv = editor("/items/:slug")

      assert has_element?(lv, "#page-hero h1", "Shoes")
      assert has_element?(lv, "#shop-header[data-path='/items/shoes']")
    end

    test "an event the site's own pages send leaves the page as it was, and says nothing" do
      lv = editor("/terms")
      before = render(lv)

      log =
        ExUnit.CaptureLog.capture_log([level: :warning], fn ->
          render_hook(lv, "filter", %{})
        end)

      assert render(lv) == before
      assert log == ""
    end

    test "an event nobody handles leaves the page as it was, and says how to fix it" do
      lv = editor("/terms")
      before = render(lv)

      log =
        ExUnit.CaptureLog.capture_log([level: :warning], fn ->
          render_hook(lv, "filtre", %{})
        end)

      assert render(lv) == before
      assert log =~ ~s("filtre")
      assert log =~ "page_events:"
    end

    test "an event nobody handles is named in the log, cut short" do
      lv = editor("/terms")
      event = String.duplicate("x", 200)

      log =
        ExUnit.CaptureLog.capture_log([level: :warning], fn ->
          render_hook(lv, event, %{})
        end)

      assert log =~ String.duplicate("x", 80)
      refute log =~ String.duplicate("x", 81)
    end

    test "one of the editor's own events it can't use says so, not where to add it" do
      lv = editor("/terms")
      before = render(lv)

      log =
        ExUnit.CaptureLog.capture_log([level: :warning], fn ->
          render_hook(lv, "move", %{"key" => "hero", "dir" => "sideways"})
        end)

      assert render(lv) == before
      assert log =~ "`move` with parameters it can't use"
      assert log =~ "sideways"
      refute log =~ "page_events:"
    end

    test "a section with nothing to show is drawn as a stand-in that opens" do
      news = section_of("/about", :news)
      lv = editor("/about")

      assert has_element?(
               lv,
               "#edit-#{news.key} .bb-edit-stand-in",
               "What's on · Nothing to show yet: there's no news, and no words for when there's none."
             )

      open(lv, news.key)

      assert has_element?(lv, "#edit-#{news.key} #section-editor")
      assert has_element?(lv, "#edit-#{news.key} [contenteditable][data-path='head.heading']")
    end

    test "another admin's removal of the open section closes it, and says so" do
      lv = editor("/about")
      add(lv, "text_media")
      new = List.last(draft("/about").sections)
      open(lv, new.key)

      {:ok, _} =
        Pages.change_draft(
          "/about",
          fn _draft, sections -> Shop.Pages.destroy_section(sections[new.key], @opts) end,
          @opts
        )

      assert has_element?(lv, "#flash-info", "Someone else removed this section.")
      refute has_element?(lv, "#section-editor")
    end
  end

  describe "publishing" do
    setup do: about!()

    test "with no changes, the bar says how to start, and offers nothing to publish" do
      lv = editor("/about")

      assert has_element?(lv, "#draft-status[role='status']", "Click any section to change it.")
      assert has_element?(lv, "#discard-changes[disabled]")
      assert has_element?(lv, "#commit-changes[disabled]")
    end

    test "the first change says so, and still does after a refresh" do
      lv = editor("/about")

      add(lv, "text_media")
      assert has_element?(lv, "#draft-status", "aren't on the site yet")
      assert has_element?(lv, "#editor-bar time[phx-hook]")

      lv = editor("/about")
      assert has_element?(lv, "#draft-status", "aren't on the site yet")
      assert has_element?(lv, "#page-list a[data-draft]", "About")
    end

    test "discard sits left of publish" do
      lv = editor("/about")
      assert has_element?(lv, "#editor-bar #discard-changes + #commit-changes", "Publish")
    end

    test "publish and discard both ask first" do
      lv = editor("/about")
      add(lv, "text_media")

      assert has_element?(lv, "#commit-changes[data-confirm^='Put your changes on the site?']")
      assert has_element?(lv, "#discard-changes[data-confirm^='Discard your changes']")
    end

    test "publish puts the changes on the site" do
      lv = editor("/about")
      add(lv, "text_media")

      lv |> element("#commit-changes") |> render_click()

      assert has_element?(lv, "#flash-info", "Published. Your changes are on the site.")
      assert has_element?(lv, "#commit-changes[disabled]")
      assert :text_media in types("/about")
    end

    test "discard throws the changes away, and the words being typed with them" do
      lv = editor("/about")
      add(lv, "text_media")
      new = List.last(draft("/about").sections)
      open(lv, new.key)

      lv |> element("#discard-changes") |> render_click()

      assert_push_event(lv, "words:reset", %{})
      assert no_draft?("/about")
      refute :text_media in types("/about")
      refute has_element?(lv, "#edit-#{new.key}")
      assert has_element?(lv, "#discard-changes[disabled]")
      refute has_element?(lv, "#flash-info", "Someone else")
    end

    test "publishing keeps the open section open" do
      lv = editor("/about")
      add(lv, "text_media")
      open(lv, "story")

      lv |> element("#commit-changes") |> render_click()

      assert has_element?(lv, "#edit-story #section-editor")
      refute has_element?(lv, "#flash-info", "Someone else")
    end

    test "discarding keeps open a section the live page has" do
      lv = editor("/about")
      add(lv, "text_media")
      open(lv, "story")

      lv |> element("#discard-changes") |> render_click()

      assert has_element?(lv, "#edit-story #section-editor")
      refute has_element?(lv, "#flash-info", "Someone else")
    end

    test "publish and discard hand the focus to the page picker" do
      lv = editor("/about")
      add(lv, "text_media")

      for button <- ~w(#commit-changes #discard-changes) do
        [click] =
          lv
          |> element(button)
          |> render()
          |> LazyHTML.from_fragment()
          |> LazyHTML.attribute("phx-click")

        assert click =~ ~s("focus") and click =~ "#page-picker-toggle"
      end
    end

    test "marks the sections that break a rule, and won't publish until they're fixed" do
      put_shop!(rules: [GroundRule])
      lv = editor("/about")
      # After the shared band, on the same ground.
      add(lv, "band")
      band = List.last(draft("/about").sections)
      # A new section arrives open; closed, it shows its mark.
      render_click(lv, "close_section")

      assert has_element?(lv, "#edit-#{band.key}[data-issue='error'] .bb-edit-section-issue")
      assert has_element?(lv, "#open-#{band.key}", "Needs fixing")
      assert has_element?(lv, "#commit-changes[disabled][aria-describedby='commit-blockers']")

      assert has_element?(
               lv,
               "#draft-status #commit-blockers",
               "1 thing needs fixing before you publish."
             )
    end

    test "a publish the rules refuse leaves the draft, and says why" do
      put_shop!(rules: [GroundRule])
      before = types("/about")
      lv = editor("/about")
      add(lv, "band")

      # The button is disabled, so this is a stale tab, or a second admin's
      # change landing between render and click.
      render_click(lv, "commit", %{})

      assert has_element?(lv, "#flash-error", "can't share a ground")
      assert has_element?(lv, "#discard-changes:not([disabled])")
      assert types("/about") == before
    end

    test "a section still holding the words it arrived with is worth a look" do
      lv = editor("/about")
      add(lv, "text_media")
      new = List.last(draft("/about").sections)
      render_click(lv, "close_section")

      assert has_element?(lv, "#edit-#{new.key}[data-issue='warning']")
      assert has_element?(lv, "#open-#{new.key}", "Worth a look")
      refute has_element?(lv, "#commit-changes[disabled]")
    end

    test "follows another admin's changes to the same draft" do
      lv = editor("/about")
      {:ok, _draft} = Shop.Pages.edit_page("/about", @opts)

      assert has_element?(lv, "#discard-changes:not([disabled])")

      :ok = Shop.Pages.discard_page("/about", @opts)
      assert has_element?(lv, "#discard-changes[disabled]")
    end
  end

  describe "two columns" do
    setup do: about!()

    defp columns_in(sections), do: Enum.find(sections, &(&1.content.type == :columns))

    test "can swap sides" do
      cols = section_of("/about", :columns)
      [left, right] = Enum.map(cols.children, & &1.key)
      lv = editor("/about")

      render_click(lv, "swap_columns", %{"key" => cols.key})

      assert Enum.map(columns_in(draft("/about").sections).children, & &1.key) == [right, left]
      assert Enum.map(section_of("/about", :columns).children, & &1.key) == [left, right]
      assert has_element?(lv, "#edit-#{cols.key} [data-columns] > :first-child > #edit-#{right}")
    end

    test "a column's header goes up to its Two columns, drawn with its columns closed" do
      cols = section_of("/about", :columns)
      [left, right] = cols.children
      lv = editor("/about")
      open(lv, left.key)

      assert has_element?(lv, "#section-controls > #section-open-columns")
      # A column goes and moves only with its pair.
      refute has_element?(lv, "#section-remove")
      refute has_element?(lv, "#section-move-up")
      refute has_element?(lv, "#section-move-down")
      lv |> element("#section-open-columns") |> render_click()

      assert has_element?(lv, "#edit-#{cols.key}[data-open='true'] > #section-editor")
      refute has_element?(lv, "#section-open-columns")

      for child <- [left, right] do
        assert has_element?(lv, "#edit-#{child.key}[data-open='false'][phx-click]")
        assert has_element?(lv, "#open-#{child.key}")
      end
    end

    test "the pair's header removes, lays out, swaps, and closes it" do
      cols = section_of("/about", :columns)
      [left, right] = Enum.map(cols.children, & &1.key)
      lv = editor("/about")
      open(lv, cols.key)

      assert has_element?(lv, "#section-remove[phx-value-key='#{cols.key}']")
      assert has_element?(lv, "#section-done")

      for {variant, words} <- [even: "Even", wide_left: "Wide left", wide_right: "Wide right"],
          do:
            assert(
              has_element?(lv, "#section-layout label[for='section-variant-#{variant}']", words)
            )

      lv |> element("#section-swap-columns") |> render_click()

      assert Enum.map(columns_in(draft("/about").sections).children, & &1.key) == [right, left]
      assert has_element?(lv, "#edit-#{cols.key} [data-columns] > :first-child > #edit-#{right}")
      assert has_element?(lv, "#edit-#{cols.key}[data-open='true'] > #section-editor")

      lv |> form("#section-settings", %{"variant" => "wide_right"}) |> render_change()
      assert columns_in(draft("/about").sections).content.value.variant == :wide_right
      assert has_element?(lv, "#edit-#{cols.key} [data-columns='wide_right']")
    end

    test "a Shared section in a column goes up to its Two columns too" do
      cols = section_of("/about", :columns)
      [_left, right] = cols.children

      {:ok, shared} =
        Pages.change_draft(
          "/about",
          fn draft, sections ->
            # The library's band goes on the page once, in the column.
            :ok = Shop.Pages.destroy_section(sections["promo-here"], @opts)
            :ok = Shop.Pages.destroy_section(sections[right.key], @opts)

            Shop.Pages.create_section(
              %{
                version_id: draft.id,
                parent_id: sections[cols.key].id,
                content: %Ash.Union{
                  type: :shared,
                  value: Billboard.Component.build!(:shared, %{key: "promo"})
                }
              },
              @opts
            )
          end,
          @opts
        )

      lv = editor("/about")
      open(lv, shared.key)

      assert has_element?(lv, "#edit-#{shared.key} > #section-editor #section-open-columns")
      refute has_element?(lv, "#section-move-up")
      lv |> element("#section-open-columns") |> render_click()
      assert has_element?(lv, "#edit-#{cols.key}[data-open='true'] > #section-editor")
    end

    test "only Two columns offer to swap sides" do
      lv = editor("/about")
      open(lv, "story")
      refute has_element?(lv, "#section-swap-columns")
      refute has_element?(lv, "#section-open-columns")
      refute has_element?(lv, "#section-fixed")
    end

    test "only two columns can swap sides" do
      hero = hd(keys("/about"))
      lv = editor("/about")

      render_click(lv, "swap_columns", %{"key" => hero})

      refute has_element?(lv, "#flash-error")
      assert no_draft?("/about")
    end
  end

  describe "adding a section" do
    setup do: about!()

    test "there's a place to add one after the hero and after every section, marked as the editor's own" do
      [_hero | body] = keys("/about")
      lv = editor("/about")

      assert has_element?(lv, "main > #section-gap-1:first-child[data-editor-ui]")
      assert has_element?(lv, "#section-gap-1 #section-add-at-1", "Add a section")
      refute has_element?(lv, "#section-add-at-0")

      for {key, i} <- Enum.with_index(body, 2) do
        assert has_element?(lv, "#edit-#{key} + #section-gap-#{i} #section-add-at-#{i}")
      end

      refute has_element?(lv, "#section-palette")
    end

    test "the palette opens at its place, each entry with its picture and what it's for" do
      lv = editor("/about")

      palette(lv, 2)

      assert has_element?(lv, "#section-add-at-2[aria-expanded='true']")
      assert has_element?(lv, "#section-gap-2 #section-palette[role='dialog']")
      assert has_element?(lv, "#section-palette-text_media [data-component='text_media']")

      assert has_element?(
               lv,
               "#section-palette-text_media",
               Billboard.Catalogue.fetch!(:text_media).hint
             )

      # The focus goes to its first entry.
      assert_push_event(lv, "editor:focus", %{ids: ["section-palette-band", "section-palette"]})

      # Another place moves it there.
      palette(lv, 3)
      refute has_element?(lv, "#section-gap-2 #section-palette")
      assert has_element?(lv, "#section-gap-3 #section-palette")

      lv |> element("#section-palette-close") |> render_click()
      refute has_element?(lv, "#section-palette")
      assert has_element?(lv, "#section-add-at-3[aria-expanded='false']")
      assert_push_event(lv, "editor:focus", %{ids: ["section-add-at-3" | _]})
    end

    test "a click away closes the palette only where it is open" do
      lv = editor("/about")
      palette(lv, 2)

      render_click(lv, "close_palette", %{"at" => "3"})
      assert has_element?(lv, "#section-palette")

      render_click(lv, "close_palette", %{"at" => "2"})
      refute has_element?(lv, "#section-palette")
    end

    test "adding at a place puts the section there, and opens it" do
      [hero, first, second | rest] = keys("/about")
      lv = editor("/about")

      add(lv, "text_media", 2)

      assert [^hero, ^first, new, ^second | ^rest] = Enum.map(draft("/about").sections, & &1.key)

      assert has_element?(lv, "#section-gap-2 + #edit-#{new}[data-open='true'] #section-editor")
      refute has_element?(lv, "#section-palette")
      # The focus goes to the new section's first words, ready to be typed over.
      assert_push_event(lv, "editor:focus", %{words: ^new, select: true})
    end

    test "a site that narrows Text and image's variants still draws the palette, and adds one" do
      put_shop!(options: [text_media: [variant: [:media_right, :text_only]]])
      lv = editor("/about")

      palette(lv)
      assert has_element?(lv, "#section-palette-text_media [data-component='text_media']")

      lv |> element("#section-palette button[phx-value-component='text_media']") |> render_click()

      assert %{content: %{type: :text_media, value: %{variant: :text_only}}} =
               List.last(draft("/about").sections)
    end

    test "adding right after the hero puts the section first in the page" do
      [hero, first | _] = keys("/about")
      lv = editor("/about")

      add(lv, "band", 1)

      assert [^hero, new, ^first | _] = Enum.map(draft("/about").sections, & &1.key)
      assert has_element?(lv, "main > #section-gap-1:first-child + #edit-#{new}")
    end

    test "a disabled entry says why, and can't be added" do
      lv = editor("/about")
      palette(lv, 2)

      # Marked, not disabled, so the keyboard reaches it and its reason is
      # read out; it sends nothing.
      assert has_element?(
               lv,
               "#section-palette-news[aria-disabled='true']:not([disabled]):not([phx-click])",
               "What's on is already on this page."
             )

      render_click(lv, "add_section", %{"component" => "news", "at" => "2"})

      assert no_draft?("/about")
      assert has_element?(lv, "#flash-error", "What's on is already on this page.")
    end

    test "nothing is added to a fixed page" do
      lv = editor("/terms")

      render_click(lv, "add_section", %{"component" => "band", "at" => "2"})

      assert no_draft?("/terms")
      assert has_element?(lv, "#flash-error")
    end

    test "nothing is added, and the palette doesn't open, while viewing as a visitor" do
      lv = editor("/about")
      lv |> element("#mode-view") |> render_click()

      render_click(lv, "palette", %{"at" => "2"})
      render_click(lv, "add_section", %{"component" => "band", "at" => "2"})

      assert no_draft?("/about")
      refute has_element?(lv, "#section-palette")
    end

    test "Two columns go where they're added, holding their two sections" do
      [hero, first | rest] = keys("/about")
      lv = editor("/about")

      add(lv, "columns", 2)

      assert [^hero, ^first, columns | ^rest] = draft("/about").sections |> Enum.map(& &1.key)
      new = Enum.find(draft("/about").sections, &(&1.key == columns))
      assert [%{content: %{type: :details}} = left, %{content: %{type: :details}}] = new.children
      assert has_element?(lv, "#section-gap-2 + #edit-#{columns}")

      # Its left column opens, to be typed into, under the pair.
      assert has_element?(
               lv,
               "#edit-#{columns}[data-open='false'] #edit-#{left.key}[data-open='true']"
             )

      assert_push_event(lv, "editor:focus", %{words: key, select: true})
      assert key == left.key
    end

    test "tabbing out of the palette closes it, leaving the focus where it went" do
      lv = editor("/about")
      palette(lv, 2)
      assert_push_event(lv, "editor:focus", _opened)

      render_click(lv, "close_palette", %{"at" => "2", "stay" => true})

      refute has_element?(lv, "#section-palette")
      refute_push_event(lv, "editor:focus", _focus)
    end

    test "nothing is added before the hero, or past the end" do
      lv = editor("/about")

      for at <- ["0", "99", "-1", "two"] do
        render_click(lv, "add_section", %{"component" => "band", "at" => at})
        assert no_draft?("/about")
      end

      render_click(lv, "palette", %{"at" => "0"})
      refute has_element?(lv, "#section-palette")
    end

    test "viewing as a visitor closes the palette" do
      lv = editor("/about")
      palette(lv, 2)

      lv |> element("#mode-view") |> render_click()
      lv |> element("#mode-edit") |> render_click()

      refute has_element?(lv, "#section-palette")
    end

    test "opening a section closes the palette" do
      lv = editor("/about")
      palette(lv, 2)

      open(lv, "story")

      refute has_element?(lv, "#section-palette")
    end
  end

  describe "shared sections" do
    setup do
      about!()

      make_live("/", [
        {"hero", :hero, %{heading: "Everything for the shop"}},
        {"promo-home", :shared, %{key: "promo"}}
      ])
    end

    # Puts a second section in the live library, to swap to.
    defp library_with_quiet do
      {:ok, draft} = Shop.Pages.edit_page(nil, @opts)
      section_fixture(draft, :points, %{points: [%{title: "Quiet"}]}, %{key: "quiet"})
      {:ok, _live} = Shop.Pages.commit_page(nil, @opts)
      :ok
    end

    test "a shared section's header says where it's shared, and takes no settings or words" do
      lv = editor("/about")
      open(lv, "promo-here")

      assert has_element?(lv, "#section-controls", "Shared section")

      assert has_element?(
               lv,
               "#section-shared-uses",
               "Shared with 2 pages: this one and Home."
             )

      assert has_element?(
               lv,
               "#section-remove[phx-value-key='promo-here']",
               "Remove from this page"
             )

      assert has_element?(lv, "#section-move-up")
      assert has_element?(lv, "#section-done")
      refute has_element?(lv, "#section-more")
      refute has_element?(lv, "[contenteditable]")
    end

    test "a section another two pages share counts them" do
      item!()
      lv = editor("/items/:slug")
      add(lv, "shared")
      new = List.last(draft("/items/:slug").sections)

      assert has_element?(
               lv,
               "#edit-#{new.key} #section-shared-uses",
               "Shared with 3 pages: this one, Home, and About."
             )
    end

    test "Swap for another leaves out what the page already places" do
      library_with_quiet()
      lv = editor("/about")
      add(lv, "shared")
      open(lv, "promo-here")

      assert has_element?(lv, "#section-setting-key option[value='promo']")
      refute has_element?(lv, "#section-setting-key option[value='quiet']")
    end

    test "a section only this page places says so" do
      library_with_quiet()
      lv = editor("/about")
      add(lv, "shared")
      new = List.last(draft("/about").sections)
      assert new.content.value.key == "quiet"

      assert has_element?(
               lv,
               "#edit-#{new.key} #section-shared-uses",
               "Only on this page so far."
             )
    end

    test "Swap for another places another library section" do
      library_with_quiet()
      lv = editor("/about")
      open(lv, "promo-here")

      assert has_element?(lv, "#section-setting-key", "Swap for another")
      assert has_element?(lv, "#section-setting-key option[value='quiet']")

      lv
      |> form("#section-settings")
      |> render_change(%{"section" => %{"content" => %{"key" => "quiet"}}})

      render(lv)

      shared = Enum.find(draft("/about").sections, &(&1.key == "promo-here"))
      assert shared.content.value.key == "quiet"
      assert has_element?(lv, "#edit-promo-here #section-quiet")
      assert has_element?(lv, "#section-shared-uses", "Only on this page so far.")
    end

    test "Edit in library opens it there" do
      lv = editor("/about")
      open(lv, "promo-here")

      assert has_element?(
               lv,
               "#section-edit-in-library[href='/pages?open=promo&page=shared']"
             )

      lv |> element("#section-edit-in-library") |> render_click()

      assert_patch(lv, "/pages?open=promo&page=shared")
      assert has_element?(lv, "#page-list a[aria-current='page']", "Shared sections")
      assert has_element?(lv, "#edit-promo #section-editor[data-section='promo']")
      assert has_element?(lv, "#edit-promo [contenteditable]")
      # The library opens wherever the page was scrolled, so the section
      # is brought into view.
      assert_push_event(lv, "editor:reveal", %{key: "promo"})
    end

    test "Remove from this page takes it off the page, after asking" do
      lv = editor("/about")
      open(lv, "promo-here")

      assert has_element?(lv, "#section-remove[data-confirm]")
      lv |> element("#section-remove") |> render_click()

      refute :shared in draft_types("/about")
      assert Map.has_key?(Pages.shared_sections(), "promo")
    end
  end

  describe "the library" do
    test "has a plain heading and what it's for, in place of a hero" do
      lv = editor(nil)

      assert has_element?(lv, "#page-hero h1", "Shared sections")

      assert has_element?(
               lv,
               "#page-hero",
               "Sections you can place on several pages. Changes here publish on their own."
             )

      refute has_element?(lv, "#page-hero[data-edit-section]")
    end

    test "has a place to add a section before its first" do
      [first | _] = keys(nil)
      lv = editor(nil)

      assert has_element?(lv, "main > #section-gap-0:first-child + #edit-#{first}")

      add(lv, "text_media", 0)

      assert [new, ^first] = Enum.map(draft(nil).sections, & &1.key)
      assert has_element?(lv, "#edit-#{new} #section-editor")
    end

    test "draws and edits a section, and says which pages show it" do
      about!()

      make_live("/", [
        {"hero", :hero, %{heading: "Everything for the shop"}},
        {"promo-home", :shared, %{key: "promo"}}
      ])

      lv = editor(nil)
      open(lv, "promo")

      assert has_element?(lv, "#section-shared-uses", "On 2 pages: Home and About.")
      edit_words(lv, "heading", "Learn with us")

      assert [%{content: %{value: %{heading: "Learn with us"}}}] = draft(nil).sections
      assert has_element?(lv, "#commit-changes:not([disabled])")
    end
  end

  describe "the open section's header" do
    setup do: about!()

    test "removes the section, after asking, from its left end" do
      lv = editor("/about")
      open(lv, "story")

      assert has_element?(
               lv,
               "#section-controls #section-remove[data-confirm='Remove this section?'][phx-value-key='story']"
             )

      lv |> element("#section-remove") |> render_click()

      refute "story" in Enum.map(draft("/about").sections, & &1.key)
      refute has_element?(lv, "#section-editor")
      # The focus goes to the section that took its place.
      assert_push_event(lv, "editor:focus", %{ids: ["open-whats-on" | _]})
    end

    test "the hero is never removed or moved, and says why" do
      lv = editor("/about")
      open(lv, "hero")

      assert has_element?(lv, "#section-controls", "Every page opens with its hero.")
      refute has_element?(lv, "#section-remove")
      refute has_element?(lv, "#section-move-up")
      refute has_element?(lv, "#section-move-down")
    end

    test "a fixed page's sections and a column's section don't move or go" do
      lv = editor("/terms")
      open(lv, "terms")

      assert has_element?(lv, "#section-editor")
      assert has_element?(lv, "#section-fixed", "This page's sections are fixed.")
      refute has_element?(lv, "#section-remove")
      refute has_element?(lv, "#section-move-up")
      refute has_element?(lv, "#section-move-down")
      refute has_element?(lv, "[id^='section-add-at-']")

      # Its hero says so too, in place of why a hero stays.
      open(lv, "hero")
      assert has_element?(lv, "#section-fixed", "This page's sections are fixed.")
      refute has_element?(lv, "#section-controls", "Every page opens with its hero.")

      lv = editor("/about")
      open(lv, "where")

      assert has_element?(lv, "#section-editor")
      refute has_element?(lv, "#section-remove")
      refute has_element?(lv, "#section-move-up")
    end

    test "moves only where a section can go" do
      lv = editor("/about")

      open(lv, "also-here")
      refute has_element?(lv, "#section-move-up")
      assert has_element?(lv, "#section-move-down")

      open(lv, "story")
      assert has_element?(lv, "#section-move-up")
      assert has_element?(lv, "#section-move-down")

      open(lv, "promo-here")
      assert has_element?(lv, "#section-move-up")
      refute has_element?(lv, "#section-move-down")
    end

    test "a move keeps the section open, and hands the focus back to the button" do
      lv = editor("/about")
      open(lv, "story")

      lv |> element("#section-move-up") |> render_click()

      assert [_hero, "story", "also-here" | _] = Enum.map(draft("/about").sections, & &1.key)
      assert has_element?(lv, "#edit-story #section-editor")

      assert_push_event(lv, "editor:focus", %{
        ids: ["section-move-up", "section-move-down", "section-done"],
        scroll: true
      })
    end

    test "opening a section takes the focus into its header, and Done gives it back" do
      lv = editor("/about")

      lv |> element("#open-story") |> render_click()
      assert_push_event(lv, "editor:focus", %{ids: ["section-controls"]})

      lv |> element("#section-done") |> render_click()
      assert_push_event(lv, "editor:focus", %{ids: ["open-story"]})
    end

    test "lists the section's issues under its header, in place of its mark" do
      put_shop!(rules: [GroundRule])
      lv = editor("/about")
      add(lv, "band")
      band = List.last(draft("/about").sections)
      render_click(lv, "close_section")
      assert has_element?(lv, "#edit-#{band.key} .bb-edit-section-issue")

      open(lv, band.key)

      assert has_element?(lv, "#section-issues [data-level='error']", "can't share a ground")
      # Filler: a new band still says what it arrived with.
      assert has_element?(lv, "#section-issues [data-level='warning']")
      refute has_element?(lv, "#edit-#{band.key} .bb-edit-section-issue")
    end

    test "a section's issues stay with it" do
      lv = editor("/about")
      add(lv, "band")

      open(lv, "story")

      refute has_element?(lv, "#section-issues")
    end

    test "Discard drops a change the header held, and why words didn't save" do
      make_live("/", [
        {"hero", :hero, %{heading: "Everything for the shop"}},
        {"range", :text_media,
         %{variant: :text_only, head: %{heading: "Our range"}, body: "Come and see."},
         anchor: "range"}
      ])

      lv = editor("/")
      open(lv, "range")
      edit_words(lv, "body", "Ring us for opening times.")

      lv |> form("#section-settings") |> render_change(%{"section" => %{"anchor" => "main"}})
      edit_words(lv, "head.heading", "Come and look")
      assert has_element?(lv, "#section-issues #section-error-anchor")
      assert has_element?(lv, "#section-issues #words-range-head-heading-refused")

      render_click(lv, "discard", %{})
      _ = render(lv)

      refute has_element?(lv, "#section-issues")
      assert has_element?(lv, "#section-more input[name='section[anchor]'][value='range']")
    end

    test "news keeps its words for when there's none under More" do
      lv = editor("/")
      add(lv, "news")
      news = List.last(draft("/").sections)

      open(lv, news.key)

      assert has_element?(lv, "#section-more label", "When there's no news")
    end

    test "glyphs keep their words for screen readers on phones" do
      home!()
      lv = editor("/")
      open(lv, "range")

      assert has_element?(lv, "#section-layout label span.max-sm\\:sr-only", "No photo")
    end
  end

  describe "in place" do
    # A PNG signature, enough for `Uploads.store_image/1`.
    @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, "IHDR">>

    # The open section's content in the draft.
    defp draft_content(pattern, key),
      do:
        Enum.find(
          Enum.flat_map(draft(pattern).sections, &[&1 | &1.children]),
          &(&1.key == key)
        ).content.value

    defp click(lv, selector) do
      lv |> element(selector) |> render_click()
      render(lv)
    end

    setup do: about!()

    # What keeps the site's links, its actions, and their phx-clicks still
    # while editing, by click and by the keyboard, and opens and closes
    # sections, is the canvas's hook (`EditCanvas`), which a LiveViewTest
    # can't run. These tests hold what it stands on: the hook on the
    # canvas, the editor's own controls marked as its own, the buttons
    # marked with their paths, and the words of a closed section with
    # theirs; and the wrappers' clicks, which open a section without it.
    test "the canvas carries the hook that keeps the site's links still" do
      lv = editor("/about")

      assert has_element?(lv, "#edit-canvas[phx-hook='EditCanvas'][data-mode='edit']")

      lv |> element("#mode-view") |> render_click()
      assert has_element?(lv, "#edit-canvas[phx-hook='EditCanvas'][data-mode='view']")
    end

    test "a closed section's words say where they are, for a click to open them there" do
      lv = editor("/about")

      assert has_element?(lv, "#edit-story [data-words-at='points.1.title']", "Grown")
      assert has_element?(lv, "#page-hero h1 [data-words-at='heading']")

      open(lv, "story")
      refute has_element?(lv, "#edit-story [data-words-at]")
      assert has_element?(lv, "#edit-whats-on [data-words-at='head.heading']")

      lv |> element("#mode-view") |> render_click()
      refute has_element?(lv, "[data-words-at]")
    end

    test "opening a section at its words puts the focus in them" do
      lv = editor("/about")

      render_click(lv, "open_section", %{"key" => "story", "words" => "points.1.body"})

      assert has_element?(lv, "#edit-story #section-editor")

      assert_push_event(lv, "editor:focus", %{
        ids: ["words-story-points-1-body", "section-controls"]
      })
    end

    test "a new point takes the focus once it's drawn, in its words" do
      lv = editor("/about")
      open(lv, "also-here")

      click(lv, "#section-add-points")

      assert_push_event(lv, "editor:focus", %{words: "also-here", at: "points-2", select: true})
      assert has_element?(lv, "#edit-also-here #words-also-here-points-2-title[contenteditable]")
    end

    test "messages are the editor's own, so a click closes them" do
      lv = editor("/about")
      open(lv, "story")
      edit_words(lv, "points.0.title", "Founded in a shed")

      lv |> element("#discard-changes") |> render_click()

      assert has_element?(lv, "#edit-canvas [data-editor-ui].bb-editor-flash #flash-info")
    end

    test "a button opens its popover where it's drawn" do
      storefront!()
      lv = editor("/")
      open(lv, "hero")

      assert has_element?(
               lv,
               "#page-hero #section-at-actions-1[data-edit-action='actions.1'][data-editor-ui]",
               "Our story"
             )

      click(lv, "#section-at-actions-1")

      assert has_element?(lv, "#section-editor #section-button[role='dialog']")
      assert has_element?(lv, "#section-button input[name='section[content][actions][1][label]']")

      lv
      |> form("#section-button-form")
      |> render_change(%{
        "section" => %{"content" => %{"actions" => %{"1" => %{"label" => "Our history"}}}}
      })

      _ = render(lv)

      assert Enum.at(draft_content("/", "hero").actions, 1).label == "Our history"
      assert has_element?(lv, "#section-at-actions-1", "Our history")
    end

    test "buttons are marked only in the open section" do
      storefront!()
      lv = editor("/")

      refute has_element?(lv, "[data-edit-action]")

      open(lv, "range")
      assert has_element?(lv, "#edit-range #section-at-head-action")
      refute has_element?(lv, "#page-hero [data-edit-action]")
    end

    test "adds a button after the others, and opens it, up to the most" do
      home!()
      lv = editor("/")
      open(lv, "range")

      assert has_element?(
               lv,
               "#edit-range [data-editor-ui]#section-add-button-actions",
               "Add a button"
             )

      click(lv, "#section-add-button-actions")

      assert [%{kind: :call}, %{kind: :link}] = draft_content("/", "range").actions
      assert has_element?(lv, "#section-button input[name='section[content][actions][1][label]']")
      # Two is the most.
      refute has_element?(lv, "#section-add-button-actions")
    end

    test "adds a button to a heading, and a link to a point" do
      lv = editor("/about")
      open(lv, "also-here")

      assert has_element?(lv, "#edit-also-here #section-at-points-0-link", "Getting here")
      refute has_element?(lv, "#section-add-button-points-0-link")

      click(lv, "#section-add-button-points-1-link")

      assert %{label: "Your link"} = Enum.at(draft_content("/about", "also-here").points, 1).link

      # A heading with no button of its own.
      home!()
      lv = editor("/")
      open(lv, "range")

      click(lv, "#section-add-button-head-action")
      assert %{kind: :link} = draft_content("/", "range").head.action
    end

    test "a point is removed and moved from its own tools" do
      story = Enum.find(Pages.page_for("/about").sections, &(&1.key == "story"))
      [one, two, three] = Enum.map(story.content.value.points, & &1.id)
      lv = editor("/about")
      open(lv, "story")

      assert has_element?(lv, "#edit-story [data-editor-ui] #section-item-points-0-down")
      refute has_element?(lv, "#section-item-points-0-up")
      refute has_element?(lv, "#section-item-points-2-down")

      click(lv, "#section-item-points-0-down")
      assert Enum.map(draft_content("/about", "story").points, & &1.id) == [two, one, three]

      assert_push_event(lv, "editor:focus", %{
        ids: ["section-item-points-1-down", "section-item-points-1-up" | _]
      })

      click(lv, "#section-item-points-2-remove")
      assert Enum.map(draft_content("/about", "story").points, & &1.id) == [two, one]

      # A section of points keeps one.
      click(lv, "#section-item-points-1-remove")
      refute has_element?(lv, "#section-item-points-0-remove")
    end

    test "details' items have their tools" do
      item!()
      lv = editor("/items/:slug")
      open(lv, "details")

      assert has_element?(lv, "#edit-details #section-item-items-2-remove")

      click(lv, "#section-item-items-0-remove")

      assert ["Sizing", "Returns"] =
               Enum.map(draft_content("/items/:slug", "details").items, & &1.label)
    end

    test "a detail says where it shows, and every detail shows while its section is open" do
      item!()
      lv = editor("/items/:slug")

      # Sizing is for socks, which this page isn't drawn with.
      refute has_element?(lv, "#edit-details [data-words-at='items.1.label']")

      open(lv, "details")

      assert has_element?(lv, "#edit-details [data-path='items.1.label']")

      assert has_element?(
               lv,
               "#section-item-items-1-group select option[selected][value='socks']"
             )

      assert has_element?(lv, "#section-item-items-1-group", "Not shown on this page")

      lv
      |> form("#section-item-items-0-group")
      |> render_change(%{
        "section" => %{"content" => %{"items" => %{"0" => %{"only_for_group" => "hats"}}}}
      })

      _ = render(lv)

      assert [%{only_for_group: "hats"}, %{only_for_group: "socks"}, %{only_for_group: nil}] =
               draft_content("/items/:slug", "details").items
    end

    test "a photograph is added, replaced, described, and removed where it's drawn" do
      home!()
      lv = editor("/")
      open(lv, "hero")

      assert has_element?(
               lv,
               "#page-hero [data-editor-ui] #section-photo-replace",
               "Add a photograph"
             )

      assert has_element?(lv, "#page-hero #section-photo-describe")
      refute has_element?(lv, "#section-photo-remove")

      lv
      |> file_input("#photo-form-hero", :photo, [
        %{name: "room.png", content: @png, type: "image/png"}
      ])
      |> render_upload("room.png")

      _ = render(lv)

      assert %{path: "/uploads/" <> _} = draft_content("/", "hero").photo
      assert has_element?(lv, "#page-hero #section-photo-replace", "Replace")

      click(lv, "#section-photo-describe")
      assert has_element?(lv, "#section-photo input[name='photo[alt]']")

      click(lv, "#section-photo-remove")

      assert %{path: nil, label: "The shop floor"} = draft_content("/", "hero").photo
    end

    test "a layout with a photograph arrives with its placeholder, ready for one" do
      home!()
      lv = editor("/")
      open(lv, "range")
      refute has_element?(lv, "#section-photo-replace")

      lv |> form("#section-settings") |> render_change(%{"variant" => "media_right"})
      _ = render(lv)

      assert has_element?(lv, "#edit-range", "What the photograph shows")

      assert has_element?(
               lv,
               "#edit-range [data-editor-ui] #section-photo-replace",
               "Add a photograph"
             )
    end
  end

  describe "the ground" do
    # `offer/2` and `offer_cards/1` (`Billboard.Test.ShopPages`) change
    # application env, which every test that saves a section reads. This
    # module isn't async, so no other test sees it, and each test puts it
    # back.
    setup do: about!()

    defp points_content, do: draft_content("/about", "also-here")

    test "the canvas draws the section again on the surface chosen" do
      offer(["plain", "linen"])
      key = section_of("/about", :points).key
      lv = editor("/about", open: key)
      assert has_element?(lv, "#edit-#{key} [data-surface='plain']")

      lv
      |> form("#section-settings")
      |> render_change(%{
        "section" => %{"surface" => "linen"},
        "_target" => ["section", "surface"]
      })

      # The editor's save reaches the page editor after the reply.
      render(lv)

      assert has_element?(lv, "#edit-#{key} [data-surface='linen']")
      refute has_element?(lv, "#edit-#{key} [data-surface='plain']")
    end

    test "a surface chosen in another browser is shown chosen here" do
      offer(["plain", "linen"])
      key = section_of("/about", :points).key
      here = editor("/about", open: key)
      there = editor("/about", open: key)
      # The draft's section first, so the surface is all that changes.
      here
      |> form("#section-settings")
      |> render_change(%{"section" => %{"content" => %{"columns" => "3"}}})

      render(there)

      there
      |> form("#section-settings")
      |> render_change(%{
        "section" => %{"surface" => "linen"},
        "_target" => ["section", "surface"]
      })

      render(there)

      assert has_element?(here, "#section-setting-surface input[value='linen'][checked]")
    end

    test "the page editor shows a column no Ground" do
      offer(["plain", "linen"])
      [column | _] = section_of("/about", :columns).children
      lv = editor("/about", open: column.key)

      assert has_element?(lv, "#section-editor[data-section='#{column.key}']")
      refute has_element?(lv, "#section-setting-surface")
    end

    test "the canvas draws each card's Ground, which saves from there" do
      offer_cards()
      lv = editor("/about", open: "also-here")
      refute has_element?(lv, "#section-item-points-0-surface")

      lv
      |> form("#section-settings")
      |> render_change(%{"section" => %{"content" => %{"look" => "cards"}}})

      render(lv)

      assert has_element?(lv, "#edit-also-here .bb-card #section-item-points-0-surface")
      assert has_element?(lv, "#section-item-points-1-surface option[value='loud']", "Loud")

      lv
      |> form("#section-item-points-1-surface")
      |> render_change(%{
        "section" => %{"content" => %{"points" => %{"1" => %{"surface" => "loud"}}}},
        "_target" => ["section", "content", "points", "1", "surface"]
      })

      render(lv)

      assert Enum.map(points_content().points, & &1.surface) == [nil, "loud"]
      assert has_element?(lv, "#edit-also-here .bb-card.bb-surface-loud[data-surface='loud']")
      assert has_element?(lv, "#section-item-points-1-surface option[value='loud'][selected]")
    end
  end
end
