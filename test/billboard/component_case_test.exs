defmodule Billboard.ComponentCaseTest do
  @moduledoc "assert_component_works/2 passes a component that works, and names the fix for one that doesn't."
  use Billboard.ComponentCase,
    endpoint: Billboard.Test.Endpoint,
    repo: Billboard.Test.Repo,
    async: false

  import Billboard.Test.Env

  alias Billboard.ComponentCase
  alias Billboard.Components
  alias Billboard.Test.{Broken, Misdrawn}

  import Billboard.Test.MisdrawnRenderer, only: [misdraw!: 1]

  # Misdrawn is on no page's palette, so its checks name a page.
  @misdrawn [page: "/"]

  @action %{kind: :link, style: :secondary, label: "Book", path: "/book"}

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
        ComponentCase.check_open(Billboard.Test.Unwritten, page: "/")
      end

    assert error.message =~ "names `note` as words in its `editor`, but the open section"
    assert error.message =~ ~s|Words.text(@ctx, "note", @content.note)|
    refute error.message =~ "`title`"
  end

  test "checks the open section's words and fields each on its own" do
    assert_raise ExUnit.AssertionError, ~r/`note`/, fn ->
      ComponentCase.check_words(Billboard.Test.Unwritten, page: "/")
    end

    assert ComponentCase.check_fields(Billboard.Test.Unwritten, page: "/") == :ok
    assert ComponentCase.check_fields(MySite.Sections.Faq) == :ok
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

  test "finds a Shared section drawn as the library section it places, under that one's id" do
    Billboard.Test.DataCase.preserve_cache(%{})
    band = ComponentCase.Render.section(:band, %{heading: "This week's deals"}, "deals")
    library = ComponentCase.Render.version([%{band | anchor: "deals"}])

    # The live library has it too, so a Shared section never draws nothing
    # here, whether it reads `library:` or the live one.
    snapshot = Billboard.Cache.snapshot()
    Billboard.Cache.put(%{snapshot | pages: Map.put(snapshot.pages, nil, library)})

    assert ComponentCase.check_visitor(Billboard.Components.Shared,
             attrs: %{key: "deals"},
             library: library
           ) == :ok
  end

  test "refuses a module that isn't a component, and says what to add" do
    error = assert_raise ExUnit.AssertionError, fn -> assert_component_works(String) end

    assert error.message =~
             "String isn't a billboard component. Give it `use Billboard.Component`"
  end

  describe "the shop's Misdrawn" do
    test "passes the checks a section draws for, drawn as it should be" do
      assert ComponentCase.check_items(Misdrawn, @misdrawn) == :ok
      assert ComponentCase.check_visitor(Misdrawn, @misdrawn) == :ok
      assert ComponentCase.check_open(Misdrawn, @misdrawn) == :ok
      assert ComponentCase.check_glyph(Misdrawn, @misdrawn) == :ok

      with_buttons = misdrawn_attrs(%{head: %{heading: "A heading", action: @action}})
      assert ComponentCase.check_open(Misdrawn, attrs: with_buttons, page: "/") == :ok
    end
  end

  describe "for a visitor" do
    test "names the editor's own controls drawn for a visitor" do
      misdraw!([:unguarded_tools])

      error = flunked(fn -> ComponentCase.check_visitor(Misdrawn, @misdrawn) end)

      assert error =~ "Misdrawn draws the editor's own controls for a visitor"

      assert error =~
               "Guard `Parts.add_button/1` and `Parts.item_tools/1` with `Words.editing?(@ctx)`"
    end

    test "names words a visitor doesn't see" do
      misdraw!([:hidden_words])

      error = flunked(fn -> ComponentCase.check_visitor(Misdrawn, @misdrawn) end)

      assert error =~ ~s|`title` holds "Plain words", but a visitor doesn't see it|
      assert error =~ ~s|`Words.text(@ctx, "title", @content.title)`|
    end

    test "finds the section by its id, not by words that end in one" do
      misdraw!([:no_id])

      error = flunked(fn -> ComponentCase.check_visitor(Misdrawn, @misdrawn) end)

      assert error =~ "Misdrawn draws nothing for a visitor"
      assert error =~ "Draw its outer element with `id={@anchor}`"
    end

    test "names a hero that draws nothing in the page's hero block" do
      put_env_for_test(:billboard, :site, Billboard.Test.BlankHeroSite)

      error = flunked(fn -> ComponentCase.check_visitor(Broken.BlankHero) end)

      assert error =~ "Broken.BlankHero draws nothing in the page's hero block (#page-hero)"
      assert error =~ "Broken.BlankHeroRenderer.render/1"
    end

    test "names the renderer that raises" do
      misdraw!([:raises])

      error = flunked(fn -> ComponentCase.check_visitor(Misdrawn, @misdrawn) end)

      assert error =~
               "Misdrawn raises when its section is drawn for a visitor: misdrawn for a visitor"

      assert error =~ "Billboard.Test.MisdrawnRenderer.render/1"
    end
  end

  describe "open in the editor" do
    test "names an item drawn without its tools" do
      misdraw!([:no_item_tools])

      error = flunked(fn -> ComponentCase.check_fields(Misdrawn, @misdrawn) end)

      assert error =~
               ~s|draws no tools for item 0 of `points` ([id="section-item-points-0"])|

      assert error =~ "Draw `Parts.item_tools/1` in each item while the section is open"
    end

    test "names a button drawn without the editor's mark" do
      misdraw!([:bare_actions])
      attrs = misdrawn_attrs(%{actions: [@action]})

      error = flunked(fn -> ComponentCase.check_fields(Misdrawn, attrs: attrs, page: "/") end)

      assert error =~
               "draws the button at `actions.0` without the editor's mark (#section-at-actions-0)"

      assert error =~ "Draw `Parts.editable_action/1` round it while the section is open"
      refute error =~ "section editor draws no control"
    end

    test "names a head's button, there or to add, drawn without Parts.head/1" do
      misdraw!([:own_head])

      error = flunked(fn -> ComponentCase.check_fields(Misdrawn, @misdrawn) end)

      assert error =~
               "offers no way to add a button at `head.action` (#section-add-button-head-action)"

      assert error =~ "Draw the head with `Parts.head/1`"

      attrs = misdrawn_attrs(%{head: %{heading: "A heading", action: @action}})
      error = flunked(fn -> ComponentCase.check_fields(Misdrawn, attrs: attrs, page: "/") end)

      assert error =~
               "the button at `head.action` without the editor's mark (#section-at-head-action)"
    end

    test "names an item's link, there or to add, drawn without the editor's" do
      misdraw!([:bare_links])

      error = flunked(fn -> ComponentCase.check_fields(Misdrawn, @misdrawn) end)

      assert error =~ "add a button at `points.0.link` (#section-add-button-points-0-link)"
      assert error =~ "Draw `Parts.add_button/1` while the section is open"

      attrs =
        misdrawn_attrs(%{points: [%{title: "A point", link: %{label: "More", path: "/more"}}]})

      error = flunked(fn -> ComponentCase.check_fields(Misdrawn, attrs: attrs, page: "/") end)

      assert error =~
               "the button at `points.0.link` without the editor's mark (#section-at-points-0-link)"
    end

    test "names a photograph drawn without its tools" do
      misdraw!([:bare_photo])

      error = flunked(fn -> ComponentCase.check_fields(Misdrawn, @misdrawn) end)

      assert error =~ "draws no tools over its photograph `photo` (#section-photo-replace)"
      assert error =~ "inside `Parts.editable_photo/1`"
    end

    test "names words typed in place that aren't the content's" do
      misdraw!([:wrong_words])

      error = flunked(fn -> ComponentCase.check_words(Misdrawn, @misdrawn) end)

      assert error =~ "types `title` in place, but not its words"
      assert error =~ ~s|it holds "Other words" where the content holds "Plain words"|
    end

    # The LiveView's own process logs its crash.
    @tag capture_log: true
    test "names the renderer that raises in the LiveView's own process" do
      misdraw!([:raises_connected])

      error = flunked(fn -> ComponentCase.check_open(Misdrawn, @misdrawn) end)

      assert error =~
               "Misdrawn raises when its section is drawn open in the editor: misdrawn in " <>
                 "the open section, once connected"

      assert error =~ "Billboard.Test.MisdrawnRenderer.render/1"
    end

    test "names the renderer that raises as the page is first drawn" do
      misdraw!([:raises_open])

      error = flunked(fn -> ComponentCase.check_open(Misdrawn, @misdrawn) end)

      assert error =~ "raises when its section is drawn open in the editor: misdrawn in the open"
    end
  end

  describe "a glyph" do
    test "names one that draws no element" do
      misdraw!([:glyph_text])

      error = flunked(fn -> ComponentCase.check_glyph(Misdrawn, @misdrawn) end)

      assert error =~ "Misdrawn's glyph draws nothing, not one element"
    end

    test "names one that raises" do
      misdraw!([:glyph_raises])

      error = flunked(fn -> ComponentCase.check_glyph(Misdrawn, @misdrawn) end)

      assert error =~
               "raises when its section is drawn as its glyph, in the palette: misdrawn glyph"

      assert error =~ "Draw Billboard.Test.MisdrawnRenderer.glyph/1"
    end
  end

  describe "what the editor adds" do
    test "names a part the section can do without whose blank doesn't build" do
      put_site!(components: [Broken.Misparted])

      error = flunked(fn -> ComponentCase.check_items(Broken.Misparted) end)

      assert error =~
               "a `lead` added to Billboard.Test.Broken.Misparted starts as the blank of :detail"

      assert error =~ "Name the part it holds in its `editor` entry"
    end

    test "adds an item after the placeholder's, as the editor does" do
      put_site!(components: [Broken.Repeated])

      error = flunked(fn -> ComponentCase.check_items(Broken.Repeated) end)

      assert error =~ "an item added to `points` starts as the blank of :point"
      assert error =~ "give each point a title of its own"
    end
  end

  describe "the rules" do
    setup do
      put_shop!(rules: [Billboard.Test.Strict])
    end

    test "count an error about the page that the section brings" do
      error = flunked(fn -> ComponentCase.check_placeholder(Components.Band) end)

      assert error =~ "Components.Band's placeholder breaks a rule on /: this page takes no band"
      assert error =~ "Change `placeholder` in its `component` section"
    end

    test "count an error about a section inside it" do
      error = flunked(fn -> ComponentCase.check_placeholder(Components.Columns) end)

      assert error =~ "breaks a rule on /: a column takes no details; a column takes no details"
    end

    test "name the attrs given, when the test gives them" do
      error =
        flunked(fn ->
          ComponentCase.check_placeholder(Components.Band, attrs: %{heading: "x"})
        end)

      assert error =~ "Components.Band, built from the `attrs:` given, breaks a rule on /"
      assert error =~ "Change the `attrs:`, or the rule"
    end
  end

  test "names the attrs given that don't build" do
    put_site!(components: [Broken.Unbuildable])

    error = flunked(fn -> ComponentCase.check_glyph(Broken.Unbuildable, attrs: %{}) end)

    assert error =~
             "the `attrs:` given for Billboard.Test.Broken.Unbuildable don't build: add a title"
  end

  defp misdrawn_attrs(attrs),
    do: Map.merge(Billboard.SiteOptions.placeholder(:misdrawn), attrs)

  defp flunked(check) do
    error = assert_raise ExUnit.AssertionError, check
    error.message
  end
end
