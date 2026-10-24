defmodule Billboard.Sections.CardsTest do
  # Points in the cards look, on card surfaces, which the shop doesn't
  # offer. Widening both changes application env, which every test that
  # draws or saves a section reads, so this module isn't async.
  use Billboard.Test.DataCase, async: false

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Billboard.Sections
  alias Billboard.Test.Shop.{Section, Version}

  setup do
    # The cards look, and the shop's surfaces offered to cards.
    put_shop!(options: [points: [look: [:rows, :cards]]])
    put_shop!(offered: [card: ["plain", "loud"]])
  end

  defp s(type, attrs, opts) do
    %Section{
      key: opts[:key],
      anchor: opts[:anchor] || opts[:key],
      surface: opts[:surface],
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: []
    }
  end

  defp points(key, look, points),
    do: s(:points, %{look: look, columns: 3, points: points}, key: key)

  defp render_page(sections, ctx \\ %{}) do
    assigns = %{
      version: %Version{sections: [s(:hero, %{heading: "x"}, key: "hero") | sections]},
      ctx: ctx
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
  defp count(doc, selector), do: LazyHTML.query(doc, selector) |> Enum.count()

  @three [%{title: "Choose"}, %{title: "Try", surface: "loud"}, %{title: "Take home"}]

  test "the cards look draws each point as a card, with no hairline" do
    doc = render_page([points("p", :cards, @three)])

    assert count(doc, "#p .bb-point.bb-card.p-\\[var\\(--bb-card-pad\\,1\\.5rem\\)\\]") == 3
    refute has?(doc, "#p .bb-rule-top")
    assert count(doc, "#p .bb-card > .bb-item-title") == 3
    assert has?(doc, "#p > .grid.md\\:grid-cols-3 > .bb-card")
  end

  test "a card with a surface is drawn on it, and the others on the section's" do
    doc = render_page([points("p", :cards, @three)])

    assert has?(doc, "#p.bb-surface-plain[data-surface='plain']")
    assert count(doc, "#p .bb-card.bb-surface-loud[data-surface='loud']") == 1
    assert count(doc, "#p .bb-card:not([data-surface])") == 2
    refute has?(doc, "#p .bb-card.bb-surface-plain")
  end

  test "a card whose surface the site no longer offers is drawn on its section's" do
    section = points("p", :cards, @three)
    put_shop!(offered: [card: ["plain"]])

    doc = render_page([section])

    assert count(doc, "#p .bb-card") == 3
    refute has?(doc, "#p .bb-card[data-surface]")
    refute has?(doc, "#p .bb-surface-loud")
  end

  test "a point refuses a card surface the site doesn't offer" do
    assert {:error, error} =
             Billboard.Component.build(:points, %{
               look: :cards,
               points: [%{title: "A", surface: "lilac"}]
             })

    assert Exception.message(error) =~ "“lilac” isn't a surface the site offers here"
  end

  test "rows are drawn as cards where the site offers only cards" do
    section = points("p", :rows, @three)
    put_shop!(options: [points: [look: [:cards]]])

    doc = render_page([section])

    assert count(doc, "#p .bb-point.bb-card") == 3
    refute has?(doc, "#p .bb-rule-top")
  end

  test "a card's surface is drawn on no card in the rows look" do
    doc = render_page([points("p", :rows, @three)])

    assert count(doc, "#p .bb-point.bb-rule-top") == 3
    refute has?(doc, "#p .bb-card")
    refute has?(doc, "#p .bb-surface-loud")
  end

  test "cards the site no longer offers are drawn as rows" do
    section = points("p", :cards, @three)
    put_shop!(options: [points: [look: [:rows]]])

    doc = render_page([section])

    assert count(doc, "#p .bb-point.bb-rule-top") == 3
    refute has?(doc, "#p .bb-card")
  end

  describe "on a site that offers cards four to a row" do
    # Four points, as four equal cards in one row, each on its own
    # ground, and a new Points section starts as cards in four columns.
    setup do
      put_shop!(
        options: [points: [look: [:cards, :rows], columns: [4, 3, 2], points: 1..4]],
        offered: [card: ["plain", "loud"]]
      )
    end

    @four [
      %{title: "Choose", surface: "loud"},
      %{title: "Try", surface: "plain"},
      %{title: "Take home", surface: "loud"},
      %{title: "Come back", surface: "plain"}
    ]

    test "a new Points section starts as cards, in four columns" do
      assert %{look: :cards, columns: 4} =
               Billboard.Component.build!(:points, %{points: [%{title: "Choose"}]})
    end

    test "four points are drawn in a row of four, each card on its own surface" do
      doc = render_page([s(:points, %{points: @four}, key: "p")])

      assert has?(doc, "#p > .grid.md\\:grid-cols-2.lg\\:grid-cols-4")
      assert count(doc, "#p > .grid > .bb-card") == 4
      assert count(doc, "#p .bb-card.bb-surface-loud[data-surface='loud']") == 2
      assert count(doc, "#p .bb-card.bb-surface-plain[data-surface='plain']") == 2
    end

    test "four columns are drawn as four bars in the glyph" do
      section = s(:points, %{points: @four}, key: "p")
      assigns = %{section: section}

      doc =
        ~H"""
        <Sections.glyph section={@section} />
        """
        |> rendered_to_string()
        |> LazyHTML.from_fragment()

      assert count(doc, ".grid-cols-4 > .grid") == 4
    end
  end

  describe "in the open section" do
    defp open_ctx do
      %{edit: %{open: "p", add: %{at: nil}, issues: %{}, editor: nil}}
    end

    test "each card has a Ground select, with the section's surface first" do
      doc = render_page([points("p", :cards, @three)], open_ctx())

      for i <- 0..2 do
        assert has?(doc, "#section-item-points-#{i}-surface[phx-change='edit_part']")

        assert has?(
                 doc,
                 "#section-item-points-#{i}-surface select[name='section[content][points][#{i}][surface]']"
               )
      end

      assert [first, _plain, _loud] =
               doc |> LazyHTML.query("#section-item-points-0-surface option") |> Enum.to_list()

      assert LazyHTML.attribute(first, "value") == [""]
      assert has?(doc, "#section-item-points-0-surface option[value=''][selected]")
      assert has?(doc, "#section-item-points-1-surface option[value='loud'][selected]")
    end

    test "a card whose surface is no longer offered shows the section's chosen" do
      section = points("p", :cards, @three)
      put_shop!(offered: [card: ["plain"]])

      doc = render_page([section], open_ctx())

      assert has?(doc, "#section-item-points-1-surface option[value=''][selected]")
      refute has?(doc, "#section-item-points-1-surface option[value='loud']")
    end

    test "cards have no Ground where the site offers cards no surface" do
      section = points("p", :cards, @three)
      put_shop!(offered: [card: []])

      doc = render_page([section], open_ctx())

      assert count(doc, "#p .bb-card") == 3
      refute has?(doc, "[id$='-surface'] select")
    end

    test "rows have no Ground" do
      doc = render_page([points("p", :rows, @three)], open_ctx())

      refute has?(doc, "#section-item-points-0-surface")
    end
  end
end
