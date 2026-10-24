defmodule Billboard.SectionsLibraryTest do
  @moduledoc """
  Shared sections drawn from the live library (`Billboard.Pages.shared_section/1`),
  which the test sets up in the cache, so these run apart from the other
  section tests.
  """
  use Billboard.Test.DataCase, async: false

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Billboard.{Cache, Sections}
  alias Billboard.Test.Shop.{Section, Version}

  setup :preserve_cache

  defp s(type, attrs, opts) do
    %Section{
      key: opts[:key],
      anchor: opts[:anchor],
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: []
    }
  end

  defp put_library(sections) do
    snapshot = Cache.snapshot()

    Cache.put(%{
      snapshot
      | pages: Map.put(snapshot.pages, nil, %Version{status: :live, sections: sections})
    })
  end

  # With no `shared` in its ctx, a Shared section reads the live library.
  defp render_section(section) do
    assigns = %{section: section, ctx: %{site: %{name: "The shop"}}}

    ~H"""
    <main><Sections.section section={@section} ctx={@ctx} /></main>
    """
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  test "a shared section draws the live library's section" do
    put_library([s(:band, %{heading: "Visit the shop"}, key: "promo", anchor: "promo")])

    doc = render_section(s(:shared, %{key: "promo"}, key: "here", anchor: nil))
    assert doc |> LazyHTML.query("main > #promo h2") |> Enum.count() == 1
  end

  test "a shared section never draws a library section that is itself shared" do
    put_library([s(:shared, %{key: "loop"}, key: "loop", anchor: "loop")])

    doc = render_section(s(:shared, %{key: "loop"}, key: "here", anchor: nil))
    assert doc |> LazyHTML.query("main > *") |> Enum.count() == 0
  end
end
