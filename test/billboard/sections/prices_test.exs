defmodule Billboard.Sections.PricesTest do
  @moduledoc """
  The stock Prices section (`Billboard.Sections.Prices`): which rows it
  shows, by its group, the page's scope, or neither; its two layouts;
  each row's id, hook, and words; and the editor's stand-in when it
  shows none.
  """
  use Billboard.Test.DataCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Billboard.Sections
  alias Billboard.Sections.Prices
  alias Billboard.Test.Shop.{Section, Version}

  @rows [
    %{id: "boots", title: "Boots", price: "£90", unit: "a pair", group: "shoes"},
    %{id: "laces", title: "Laces", price: "£4", note: "Any colour.", group: "shoes"},
    %{id: "cap", title: "A cap", price: "from £20", group: "hats"},
    %{id: "card", title: "A gift card", price: "Free"}
  ]

  defp prices(attrs \\ %{}),
    do: %Section{
      key: "prices",
      anchor: "prices",
      content: %Ash.Union{
        type: :prices,
        value:
          Billboard.Component.build!(:prices, Map.merge(%{head: %{heading: "Prices"}}, attrs))
      },
      children: []
    }

  defp hero,
    do: %Section{
      key: "hero",
      content: %Ash.Union{type: :hero, value: Billboard.Component.build!(:hero, %{heading: "x"})},
      children: []
    }

  defp render_page(section, ctx \\ %{}, rows \\ @rows) do
    assigns = %{
      version: %Version{sections: [hero(), section]},
      ctx: ctx,
      data: %{"prices" => rows}
    }

    ~H"""
    <Sections.page
      version={@version}
      data={@data}
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
  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text()

  # The ids of the rows drawn, in order.
  defp shown(doc),
    do: doc |> LazyHTML.query("#prices li.bb-price") |> LazyHTML.attribute("id")

  defp about(scope), do: %{context: %{scope: scope}}

  describe "which rows it shows" do
    test "every row, with neither a group nor the page's" do
      assert shown(render_page(prices())) ==
               ~w(prices-boots prices-laces prices-cap prices-card)

      assert shown(render_page(prices(), about("hats"))) ==
               ~w(prices-boots prices-laces prices-cap prices-card)
    end

    test "a chosen group's rows, wherever the section is" do
      section = prices(%{group: "shoes"})

      assert shown(render_page(section)) == ~w(prices-boots prices-laces)
      assert shown(render_page(section, about("hats"))) == ~w(prices-boots prices-laces)
    end

    test "only the page's group's rows, with this_page_only on" do
      section = prices(%{this_page_only: true})

      assert shown(render_page(section, about("hats"))) == ~w(prices-cap)
      assert shown(render_page(section, about("shoes"))) == ~w(prices-boots prices-laces)
    end

    test "nothing with this_page_only on a page about nothing" do
      doc = render_page(prices(%{this_page_only: true}))

      refute has?(doc, "#prices")
      assert Sections.empty?(prices(%{this_page_only: true}), %{data: %{"prices" => @rows}})
    end

    test "a chosen group wins over this_page_only" do
      section = prices(%{group: "hats", this_page_only: true})

      assert shown(render_page(section, about("shoes"))) == ~w(prices-cap)
      assert shown(render_page(section)) == ~w(prices-cap)
    end

    test "nothing with no rows, or none of its group" do
      refute has?(render_page(prices(), %{}, []), "#prices")
      refute has?(render_page(prices(), %{}, nil), "#prices")
      refute has?(render_page(prices(%{group: "coats"})), "#prices")
    end
  end

  describe "how it's drawn" do
    test "each row's title, note, price, and unit, on its hook between hairlines" do
      doc = render_page(prices())

      assert has?(doc, "#prices.page-section li#prices-boots.bb-price.bb-rule-top")
      assert text(doc, "#prices-boots .bb-type-body") =~ "Boots"
      assert text(doc, "#prices-boots .bb-type-subheading.text-bb-subheading") =~ "£90"
      assert text(doc, "#prices-boots .text-right .bb-type-small.text-bb-ink-soft") =~ "a pair"
      assert text(doc, "#prices-laces .min-w-0 .bb-type-small.text-bb-ink-soft") =~ "Any colour."
      refute has?(doc, "#prices-cap .bb-type-small")
      assert text(doc, "#prices-card .bb-type-subheading") =~ "Free"
    end

    test "with no opening words, the head above the rows, and its note under them" do
      doc = render_page(prices(%{note: "Prices *include* VAT."}))

      assert text(doc, "#prices > .bb-section-head h2") =~ "Prices"
      refute has?(doc, "#prices > .grid")
      assert has?(doc, "#prices > .bb-measure > ul + .bb-type-small.text-bb-ink-soft em")
    end

    test "with opening words, the head, words, and action beside the rows" do
      doc =
        render_page(
          prices(%{
            body: "What things *cost*.",
            actions: [%{kind: :link, label: "Book", path: "/book", style: :primary}]
          })
        )

      assert has?(
               doc,
               "#prices > .grid.md\\:grid-cols-\\[minmax\\(0\\,5fr\\)_minmax\\(0\\,6fr\\)\\]"
             )

      assert has?(doc, "#prices > .grid > div:first-child .bb-section-head")
      assert text(doc, "#prices > .grid > div:first-child .bb-type-body") =~ "What things"
      assert has?(doc, "#prices > .grid > div:first-child a[href='/book']")
      assert has?(doc, "#prices > .grid > .bb-measure li#prices-boots")
    end

    test "with no head, the rows alone" do
      doc = render_page(prices(%{head: nil}))

      refute has?(doc, "#prices .bb-section-head")
      assert shown(doc) != []
    end
  end

  describe "in the editor" do
    defp edit_ctx(extra \\ %{}),
      do: Map.merge(%{edit: %{open: nil, add: %{at: nil}}}, extra)

    test "draws a stand-in that says why it shows nothing" do
      doc = render_page(prices(%{group: "coats"}), edit_ctx())

      assert text(doc, "#edit-prices .bb-edit-stand-in") =~
               "Prices · Nothing to show yet: there are no prices in its group."

      doc = render_page(prices(%{this_page_only: true}), edit_ctx())

      assert text(doc, "#edit-prices .bb-edit-stand-in") =~
               "it shows only this page's prices, and this page is about nothing in particular."

      doc = render_page(prices(%{this_page_only: true}), edit_ctx(about("coats")))
      assert text(doc, "#edit-prices .bb-edit-stand-in") =~ "there are no prices for this page."

      doc = render_page(prices(), edit_ctx(), [])
      assert text(doc, "#edit-prices .bb-edit-stand-in") =~ "there are no prices."
    end

    test "says why for every content" do
      assert Prices.nothing_to_show(%{group: "hats", this_page_only: true}, %{}) ==
               "there are no prices in its group."

      assert Prices.nothing_to_show(%{group: nil, this_page_only: false}, %{}) ==
               "there are no prices."
    end
  end

  describe "its toggle's hide_when" do
    alias Billboard.Sections.EditorFields

    defp holding(group), do: %{group: %{value: group}}

    test "hides Only this page's group while a group is chosen, and only then" do
      spec = EditorFields.specs(:prices)[:this_page_only]

      assert spec[:hide_when] == [group: :any]
      assert EditorFields.hidden?(holding("shoes"), spec)
      refute EditorFields.hidden?(holding(nil), spec)
      refute EditorFields.hidden?(holding(""), spec)
    end
  end
end
