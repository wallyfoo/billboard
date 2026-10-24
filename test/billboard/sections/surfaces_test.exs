defmodule Billboard.Sections.SurfacesTest do
  # Sections drawn on a second page surface, which the shop doesn't
  # offer. Widening the offer changes application env, which every test
  # that draws or saves a section reads, so this module isn't async.
  use Billboard.Test.DataCase, async: false

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Billboard.Sections
  alias Billboard.Test.Shop.{Section, Version}

  setup do
    # The shop's surfaces, with the loud one offered to page sections too.
    put_shop!(offered: [page: ["plain", "loud"]])
  end

  defp s(type, attrs, opts) do
    %Section{
      key: opts[:key],
      anchor: opts[:anchor] || opts[:key],
      surface: opts[:surface],
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: opts[:children] || []
    }
  end

  defp points(key, opts \\ []),
    do: s(:points, %{points: [%{title: "Late on Thursdays"}]}, [key: key] ++ opts)

  defp details(key), do: s(:details, %{items: [%{label: "Where", body: "Here."}]}, key: key)

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

  test "a section with a surface set in its data draws on it" do
    doc = render_page([points("a", surface: "loud")])

    assert has?(doc, "main > #a.page-section.bb-surface-loud[data-surface='loud']")
    refute has?(doc, "#a.bb-surface-plain")
  end

  test "neighbours join on the surface they share, and only on it" do
    doc =
      render_page([
        points("a"),
        points("b", surface: "loud"),
        points("c", surface: "loud"),
        points("d")
      ])

    refute has?(doc, "#b.bb-joined")
    assert has?(doc, "#c.bb-surface-loud.bb-joined")
    refute has?(doc, "#d.bb-joined")
  end

  test "a section on a band's surface doesn't join the band before it" do
    band = s(:band, %{heading: "Visit the shop"}, key: "b")
    doc = render_page([points("a"), band, points("c", surface: "loud")])

    assert has?(doc, "#c.bb-surface-loud")
    refute has?(doc, ".bb-joined")
  end

  test "columns' children draw on their parent's surface" do
    cols =
      s(:columns, %{variant: :even},
        key: "c",
        surface: "loud",
        children: [details("one"), details("two")]
      )

    doc = render_page([points("a"), cols])

    assert has?(doc, "#c.bb-surface-loud[data-surface='loud']")
    refute has?(doc, "#c.bb-joined")
    assert has?(doc, "#c > div > #one.bb-surface-loud[data-surface='loud']")
    assert has?(doc, "#c > div > #two.bb-surface-loud")
    refute has?(doc, "#c .bb-surface-plain")
  end

  test "a shared section draws on its library section's surface, not its own" do
    library = %{"promise" => points("promise", surface: "loud")}

    shared =
      s(:shared, %{key: "promise"}, key: "s1", surface: "plain")

    doc = render_page([points("a"), shared, points("c", surface: "loud")], %{shared: library})

    assert has?(doc, "main > #promise.bb-surface-loud[data-surface='loud']")
    refute has?(doc, "#promise.bb-joined")
    assert has?(doc, "#c.bb-joined")
  end

  test "in the editor, a section on another surface parts its neighbours' padding" do
    edit = %{edit: %{open: nil, add: %{at: nil}}}
    doc = render_page([points("a"), points("b", surface: "loud"), points("c")], edit)

    assert has?(doc, "#edit-b > #b.bb-surface-loud")
    refute has?(doc, ".bb-joined")
  end
end
