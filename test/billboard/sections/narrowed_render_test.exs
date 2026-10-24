defmodule Billboard.Sections.NarrowedRenderTest do
  # The open section offers to add an item only while the site's options
  # let the list hold another, so a renderer that stops reading its
  # narrowed fields (`EditorFields.narrowed/1`) fails here. Narrowing
  # changes application env, which every test that draws a section reads,
  # so this module isn't async.
  use Billboard.Test.DataCase, async: false

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Billboard.Sections
  alias Billboard.Test.Shop.{Section, Version}

  @action %{label: "Visit", path: "/about"}

  defp s(type, attrs, key) do
    %Section{
      key: key,
      anchor: key,
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: []
    }
  end

  defp hero, do: s(:hero, %{heading: "x", actions: [@action]}, "hero")

  defp text_media do
    s(
      :text_media,
      %{variant: :text_only, head: %{heading: "Dates"}, actions: [@action]},
      "tm"
    )
  end

  # The page, with the section whose key is `open` open in the editor.
  defp render_page(sections, open) do
    assigns = %{
      version: %Version{sections: sections},
      ctx: %{edit: %{open: open, add: %{at: nil}, issues: %{}, editor: nil}}
    }

    ~H"""
    <Sections.page
      version={@version}
      ctx={@ctx}
      flash={%{}}
      site={%{name: "The shop"}}
      current_path="/"
    />
    """
    |> rendered_to_string()
    |> LazyHTML.from_document()
  end

  defp has?(doc, selector), do: LazyHTML.query(doc, selector) |> Enum.count() > 0

  describe "the hero's actions" do
    test "offer another while there's room for it" do
      doc = render_page([hero()], "hero")

      assert has?(doc, "#section-add-button-actions")
    end

    test "offer none past the most the site shows" do
      put_shop!(options: [hero: [actions: 0..1]])

      doc = render_page([hero()], "hero")

      refute has?(doc, "#section-add-button-actions")
    end
  end

  describe "points" do
    defp points, do: s(:points, %{points: [%{title: "Choose"}, %{title: "Try"}]}, "p")

    test "can each be removed while the list holds more than its fewest" do
      doc = render_page([hero(), points()], "p")

      assert has?(doc, "#section-item-points-0-remove")
      assert has?(doc, "#section-item-points-1-remove")
    end

    test "can't be removed where the site needs as many as there are" do
      put_shop!(options: [points: [points: 2..3]])

      doc = render_page([hero(), points()], "p")

      refute has?(doc, "#section-item-points-0-remove")
      refute has?(doc, "#section-item-points-1-remove")
    end
  end

  describe "a value the site has stopped offering" do
    # Each section is built while the shop offers every variant, then
    # drawn after the site narrows it, as a stored section is.
    defp quote_band do
      s(:band, %{variant: :quote_right, quote: %{body: "Worth the wait."}}, "b")
    end

    test "is drawn as the site's default, in a band" do
      band = quote_band()
      assert has?(render_page([hero(), band], nil), "#b > [data-quote-side='right']")

      put_shop!(options: [band: [variant: [:quote_left, :heading]]])

      doc = render_page([hero(), band], nil)
      assert has?(doc, "#b > [data-quote-side='left']")
      refute has?(doc, "#b > [data-quote-side='right']")
    end

    test "is drawn as the site's default, in the hero" do
      hero = s(:hero, %{heading: "x", variant: :media_left, photo: %{label: "The room"}}, "hero")
      assert has?(render_page([hero], nil), "#page-hero [data-hero-media='left']")

      put_shop!(options: [hero: [variant: [:media_right, :text_only]]])

      assert has?(render_page([hero], nil), "#page-hero [data-hero-media='right']")
    end

    test "is drawn as the site's default, in two columns" do
      details = s(:details, %{items: [%{label: "Parking", body: "Round the back."}]}, "d")
      columns = %{s(:columns, %{variant: :wide_left}, "c") | children: [details, details]}

      put_shop!(options: [columns: [variant: [:even]]])

      assert has?(render_page([hero(), columns], nil), "#c[data-columns='even']")
    end
  end

  describe "text and image's actions" do
    test "offer another while there's room for it" do
      doc = render_page([hero(), text_media()], "tm")

      assert has?(doc, "#tm #section-add-button-actions")
    end

    test "offer none past the most the site shows" do
      put_shop!(options: [text_media: [actions: 0..1]])

      doc = render_page([hero(), text_media()], "tm")

      refute has?(doc, "#tm #section-add-button-actions")
    end
  end
end
