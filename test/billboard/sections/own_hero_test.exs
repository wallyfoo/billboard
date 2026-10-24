defmodule Billboard.Sections.OwnHeroTest do
  @moduledoc """
  A site's own hero, in the stock hero's place, draws its own block on
  the page (`Billboard.Sections.page/1`), which keeps the editor's marks
  round it.
  """
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Billboard.Sections
  alias Billboard.Sections.Words
  alias Billboard.Test.Render

  setup do
    put_site!(
      components: [Billboard.Test.OwnHero, Billboard.Test.Text],
      layout: Billboard.Test.Layout
    )
  end

  defp render_page(sections, ctx \\ %{}, opts \\ []) do
    assigns = %{
      version: %{sections: sections},
      ctx: ctx,
      heading: opts[:heading],
      lede: opts[:lede]
    }

    ~H"""
    <Sections.page
      version={@version}
      ctx={@ctx}
      flash={%{}}
      site={%{name: "The shop"}}
      heading={@heading}
      lede={@lede}
    />
    """
    |> rendered_to_string()
    |> LazyHTML.from_document()
  end

  defp has?(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count() > 0
  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text()

  defp sections,
    do: [
      Render.section(:hero, %{heading: "Come by"}, "hero"),
      Render.section(:text, %{body: "Inside."}, "words")
    ]

  test "a site's own hero draws its own markup in the hero block" do
    doc = render_page(sections())

    assert text(doc, "#page-hero #own-hero h1") =~ "Come by"
    refute has?(doc, ".bb-title")
    assert text(doc, "main") =~ "Inside."
  end

  test "open in the editor, the page marks it, and its words are typed in place" do
    doc = render_page(sections(), %{edit: %{open: "hero", issues: %{}}})

    assert has?(doc, "#page-hero[data-edit-section='hero'][data-open='true']")
    assert has?(doc, "#page-hero #own-hero ##{Words.id("hero", "heading")}")
  end

  test "a version with no hero draws its heading and lede in the stock block" do
    doc = render_page([], %{}, heading: "Shared sections", lede: "On every page.")

    assert text(doc, "#page-hero h1.bb-title") =~ "Shared sections"
    assert text(doc, "#page-hero div.bb-type-lead") =~ "On every page."
    refute has?(doc, "#own-hero")
  end
end
