defmodule Billboard.ComponentCase.RenderTest do
  @moduledoc "A section drawn as the page draws it, in the site's layout, without a LiveView."
  use Billboard.Test.DataCase, async: false

  alias Billboard.ComponentCase.Render

  test "draws a section on a page in the site's layout, for a visitor" do
    html =
      Render.page([Render.section(:faq, %{title: "Asked", questions: [%{title: "Open late?"}]})])

    assert html =~ ~s(id="shop-header")
    assert html =~ "Asked"
    refute html =~ "contenteditable"
  end

  test "draws a section with the rows the site's data gives it" do
    Process.put(:shop_reviews, [
      %{id: "r1", name: "Ann", reviewed_on: ~D[2026-01-05], quote: "Lovely."}
    ])

    html = Render.page([Render.section(:reviews, %{})])

    assert html =~ "Lovely."
  end

  test "draws the hero in the layout's hero slot" do
    html = Render.page([Render.section(:hero, %{heading: "Welcome"}, "hero")])
    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.query(".bb-surface-loud #page-hero") |> LazyHTML.text() =~
             "Welcome"
  end
end
