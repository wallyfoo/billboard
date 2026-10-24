defmodule Billboard.Sections.EmptyTest do
  # A case with the database, for a Shared section that reads the live
  # library.
  use Billboard.Test.DataCase, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Billboard.{Catalogue, Sections}
  alias Billboard.Test.Shop.Section

  defp section(key, type, attrs) do
    %Section{
      key: key,
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: []
    }
  end

  defp ctx(section, data, opts) do
    %{
      data: %{section.key => data},
      site: %{name: "The shop"},
      context: opts[:context] || %{},
      state: %{},
      shared: opts[:shared] || %{}
    }
  end

  # The section as a visitor sees it, with nothing but whitespace when it
  # draws nothing.
  defp blank?(section, ctx) do
    assigns = %{section: section, ctx: ctx}

    ~H"""
    <Sections.section section={@section} ctx={@ctx} />
    """
    |> rendered_to_string()
    |> String.trim()
    |> Kernel.==("")
  end

  defp head, do: %{heading: "Heading"}
  defp detail(scope), do: %{label: "Label", body: "Words.", only_for_group: scope}

  # Every case for each component that can draw nothing: its content's
  # words that show without data, and its data (none, empty, or some).
  defp cases(:reviews) do
    review = %{id: "r1", quote: "Lovely.", name: "Client", reviewed_on: ~D[2026-05-01]}

    for note <- [nil, "From our visitors."],
        data <- [nil, [], [review]],
        do: {%{note: note}, data, []}
  end

  defp cases(:news) do
    post = %{id: "n1", title: "Late", body: "Open late.", published_on: ~D[2026-09-12]}

    for empty <- [nil, "No news yet."],
        data <- [nil, [], [post]],
        do: {%{head: head(), empty: empty}, data, []}
  end

  defp cases(:details) do
    for head <- [nil, head()],
        only <- [nil, "shoes", "hats"],
        do: {%{head: head, items: [detail(only)]}, nil, [context: %{scope: "shoes"}]}
  end

  defp cases(:shared) do
    library = %{
      "band" => section("band", :band, %{heading: "Visit the shop"}),
      "details" => section("details", :details, %{items: [detail("hats")]}),
      "nested" => section("nested", :shared, %{key: "band"})
    }

    for key <- ["band", "details", "nested", "gone"],
        do: {%{key: key}, nil, [shared: library, context: %{scope: "shoes"}]}
  end

  test "the components that can draw nothing are those with empty?/3" do
    exporting =
      for type <- Catalogue.keys(),
          module = Billboard.Renderer.for!(type),
          Code.ensure_loaded?(module),
          function_exported?(module, :empty?, 3),
          do: type

    assert Enum.sort(Sections.emptiable()) == Enum.sort(exporting)
    assert Enum.sort(Sections.emptiable()) == ~w(details news reviews shared)a
  end

  test "empty? says whether a visitor sees nothing of the section" do
    for type <- Sections.emptiable(), {attrs, data, opts} <- cases(type) do
      section = section("s1", type, attrs)
      ctx = ctx(section, data, opts)

      assert Sections.empty?(section, ctx) == blank?(section, ctx),
             "#{type}: #{inspect(attrs)} with #{inspect(data)}"
    end
  end

  test "each component can draw nothing, and something" do
    for type <- Sections.emptiable() do
      results =
        for {attrs, data, opts} <- cases(type), uniq: true do
          section = section("s1", type, attrs)
          Sections.empty?(section, ctx(section, data, opts))
        end

      assert Enum.sort(results) == [false, true], "#{type}"
    end
  end

  test "each says why it draws nothing, for the editor's stand-in" do
    for type <- Sections.emptiable() do
      module = Billboard.Renderer.for!(type)
      assert function_exported?(module, :nothing_to_show, 2), "#{type}"
    end
  end
end
