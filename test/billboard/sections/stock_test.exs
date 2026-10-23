defmodule Billboard.Sections.StockTest do
  @moduledoc """
  Every stock component, built from its placeholder and from full
  content, draws for a visitor and open in the editor, with its words
  typed into, and draws its glyph.
  """
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Billboard.Test.Render

  alias Billboard.Components

  @stock [
    Components.Hero,
    Components.Band,
    Components.Points,
    Components.TextMedia,
    Components.Details,
    Components.Reviews,
    Components.News
  ]

  setup do
    put_site!(
      components: @stock,
      actions: Billboard.Test.Actions,
      context: Billboard.Test.Context
    )
  end

  @full %{
    band: %{heading: "Visit", body: "Open daily.", action: %{label: "Come in", path: "/visit"}},
    points: %{head: %{heading: "Why us"}, points: [%{title: "Near", body: "Round the corner."}]},
    text_media: %{
      head: %{heading: "Our shop"},
      body: "Since 1999.",
      photo: %{label: "The counter"}
    },
    details: %{items: [%{label: "Parking", body: "Behind the shop.", only_for_group: "shoes"}]},
    reviews: %{note: "From our customers."},
    news: %{head: %{heading: "What's on"}, empty: "Nothing new yet."}
  }

  @data %{
    reviews: [%{id: "r1", name: "Ana", reviewed_on: ~D[2026-10-01], quote: "Lovely."}],
    news: [%{id: "n1", published_on: ~D[2026-10-02], title: "Open late", body: "On Fridays."}]
  }

  for {type, attrs} <- @full do
    test "#{type} draws for a visitor, and open with its words typed into" do
      section = section(unquote(type), unquote(Macro.escape(attrs)))
      ctx = %{data: %{"s1" => @data[unquote(type)]}, context: %{scope: "shoes"}}

      visitor = visitor(section, ctx)

      open =
        open(section, Map.put(ctx, :choices, %{scope: Billboard.Test.Context.choices(:scope)}))

      assert visitor =~ ~s(id="section-s1")
      refute visitor =~ "contenteditable"
      assert open =~ "bb-inline-words"
      assert glyph(section) =~ "<span"
    end
  end

  test "each draws from its placeholder too" do
    for module <- @stock, key = Billboard.Component.Info.component_key!(module), key != :hero do
      section = section(key, Billboard.Catalogue.placeholder(key))
      assert is_binary(open(section))
    end
  end

  test "every stock component names its renderer, reads only declared context, and goes on every kind" do
    for module <- @stock do
      assert Billboard.Component.Info.component_renderer!(module)
      assert Billboard.Component.Info.component_kinds!(module) == :all
    end

    assert Billboard.Component.Info.component_context!(Components.Hero) == [:bindings]
    assert Billboard.Component.Info.component_context!(Components.Details) == [:scope]
  end
end
