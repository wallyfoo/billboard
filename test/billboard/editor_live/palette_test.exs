defmodule Billboard.EditorLive.PaletteTest do
  @moduledoc """
  What a page may add, by category, each with its glyph and what it's for
  or why it can't be added now, and the places the palette opens.
  """
  # A case with the database, for the shop's pages and its library.
  use Billboard.Test.DataCase, async: false

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Billboard.{Catalogue, Directory}
  alias Billboard.EditorLive.Palette
  alias Billboard.Test.Shop.Section

  defp s(type, attrs, key) do
    %Section{
      key: key,
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: []
    }
  end

  defp hero, do: s(:hero, %{heading: "x"}, "hero")
  defp band(key), do: s(:band, %{heading: "Visit the shop"}, key)

  # The categories that hold a component but the hero, in order.
  defp offered_categories,
    do: Enum.uniq(for(e <- Catalogue.entries(), e.key != :hero, do: e.category))

  defp keys(options), do: for({_category, entries} <- options, o <- entries, do: o.entry.key)

  defp option(options, key),
    do: Enum.find_value(options, fn {_c, os} -> Enum.find(os, &(&1.entry.key == key)) end)

  describe "options/3" do
    test "offers a free page every component its kind takes, by category, but the hero" do
      options = Palette.options(Directory.fetch!("/"), [hero()], [band("promo")])

      assert Enum.map(options, &elem(&1, 0)) == offered_categories()

      for {category, entries} <- options, o <- entries do
        assert o.entry.category == category
      end

      assert keys(options) == Catalogue.keys() -- [:hero]
      assert Enum.all?(options, fn {_c, os} -> Enum.all?(os, &(&1.disabled == nil)) end)
    end

    test "offers an item page only what its kind takes" do
      keys = keys(Palette.options(Directory.fetch!("/items/:slug"), [hero()], [band("promo")]))

      assert :shared in keys
      refute :columns in keys
      refute :band in keys
      refute :points in keys
    end

    test "offers the library no Shared section, and a fixed page nothing" do
      refute :shared in keys(Palette.options(Directory.fetch!(nil), [], []))
      assert Palette.options(Directory.fetch!("/terms"), [hero()], []) == []
    end

    test "says why a component at its most on the page can't be added, counting columns' too" do
      news = s(:news, %{head: %{heading: "What's on"}}, "n")
      columns = %{s(:columns, %{}, "c") | children: [news, s(:text, %{body: "x"}, "t")]}

      options = Palette.options(Directory.fetch!("/"), [hero(), columns], [band("promo")])

      assert option(options, :news).disabled == "What's on is already on this page."
      assert option(options, :reviews).disabled == nil
    end

    test "says Two columns can't be added on a site where nothing fits in a column" do
      page = Directory.fetch!("/")

      put_site!(
        components: [
          Billboard.Components.Hero,
          Billboard.Components.Band,
          Billboard.Components.Columns
        ]
      )

      options = Palette.options(page, [hero()], [])

      assert option(options, :columns).disabled == "Nothing on this site fits in a column."
      assert option(options, :band).disabled == nil
    end

    test "says why a Shared section can't be added: an empty library, or every one placed" do
      page = Directory.fetch!("/")
      shared = s(:shared, %{key: "promo"}, "s1")

      assert option(Palette.options(page, [hero()], []), :shared).disabled ==
               "The shared library is empty."

      assert option(Palette.options(page, [hero(), shared], [band("promo")]), :shared).disabled ==
               "Every shared section is on this page."
    end

    test "a Shared section's glyph is the library section it would place" do
      options =
        Palette.options(Directory.fetch!("/"), [hero(), s(:shared, %{key: "promo"}, "s1")], [
          band("promo"),
          band("late")
        ])

      assert option(options, :shared).glyph.content.value.key == "late"
    end
  end

  describe "glyphs/0" do
    test "are every component's but the hero's and Shared's, as it arrives" do
      glyphs = Palette.glyphs()

      assert Enum.sort(Map.keys(glyphs)) == Enum.sort(Catalogue.keys() -- [:hero, :shared])

      assert %{children: [%{content: %{type: :details}}, %{content: %{type: :details}}]} =
               glyphs.columns
    end

    test "draw Two columns holding the first component that fits in a column, without Details" do
      put_site!(
        components: [
          Billboard.Components.Hero,
          Billboard.Test.Text,
          Billboard.Components.Columns
        ]
      )

      assert %{children: [%{content: %{type: :text}}, %{content: %{type: :text}}]} =
               Palette.glyphs().columns
    end
  end

  describe "unplaced/2 and places/1" do
    test "the library's sections no section or column places yet" do
      columns = %{s(:columns, %{}, "c") | children: [s(:shared, %{key: "promo"}, "s1")]}

      assert Palette.unplaced([band("promo"), band("late")], [hero(), columns]) == ["late"]
    end

    test "a section goes after the hero, or anywhere on a page with none" do
      assert Palette.places([hero(), band("a")]) == 1..2
      assert Palette.places([band("a")]) == 0..1
    end
  end

  describe "gap/1" do
    defp gap(at, open_at) do
      palette = Palette.options(Directory.fetch!("/"), [hero()], [band("promo")])
      assigns = %{at: at, add: %{at: open_at, palette: palette, library: %{}}}

      ~H"""
      <Palette.gap at={@at} add={@add} />
      """
      |> rendered_to_string()
      |> LazyHTML.from_fragment()
    end

    defp has?(doc, selector), do: LazyHTML.query(doc, selector) |> Enum.count() > 0
    defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text()

    test "is a place to add a section, marked as the editor's own, closed" do
      doc = gap(2, nil)

      assert has?(doc, "#section-gap-2[data-editor-ui] #section-add-at-2[aria-expanded='false']")
      assert text(doc, "#section-add-at-2") =~ "Add a section"
      refute has?(doc, "#section-palette")
    end

    test "opens the palette there, by category, each entry with its picture and what it's for" do
      doc = gap(2, 2)

      assert has?(doc, "#section-add-at-2[aria-expanded='true']")
      assert has?(doc, "#section-gap-2 #section-palette[role='dialog']")

      for category <- offered_categories() do
        assert text(doc, "#section-palette-category-#{category}") =~
                 Catalogue.category_label(category)
      end

      assert has?(doc, "#section-palette-text_media [data-component='text_media']")
      assert text(doc, "#section-palette-text_media") =~ Catalogue.fetch!(:text_media).hint

      assert has?(
               doc,
               "#section-palette-columns [data-component='columns'] [data-component='details']"
             )
    end

    test "marks an entry that can't be added, saying why, and sends nothing" do
      news = s(:news, %{head: %{heading: "What's on"}}, "n")
      palette = Palette.options(Directory.fetch!("/"), [hero(), news], [band("promo")])
      assigns = %{add: %{at: 1, palette: palette, library: %{}}}

      doc =
        ~H"""
        <Palette.gap at={1} add={@add} />
        """
        |> rendered_to_string()
        |> LazyHTML.from_fragment()

      assert has?(
               doc,
               "#section-palette-news[aria-disabled='true']:not([disabled]):not([phx-click])"
             )

      assert text(doc, "#section-palette-news") =~ "What's on is already on this page."
    end
  end
end
