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
  alias Billboard.Sections.Hero

  @stock [
    Components.Hero,
    Components.Band,
    Components.Points,
    Components.TextMedia,
    Components.Details,
    Components.Reviews,
    Components.News,
    Components.Prices
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
    news: %{head: %{heading: "What's on"}, empty: "Nothing new yet."},
    prices: %{head: %{heading: "Prices"}, body: "What things cost.", this_page_only: true}
  }

  # A word each draws from its content or its data: Details' item and
  # Prices' row are scoped to the page's aisle, so each draws only
  # because the page is about shoes.
  @words %{
    band: "Open daily.",
    points: "Round the corner.",
    text_media: "Since 1999.",
    details: "Behind the shop.",
    reviews: "Lovely.",
    news: "Open late",
    prices: "£90"
  }

  @data %{
    reviews: [%{id: "r1", name: "Ana", reviewed_on: ~D[2026-10-01], quote: "Lovely."}],
    news: [%{id: "n1", published_on: ~D[2026-10-02], title: "Open late", body: "On Fridays."}],
    prices: [%{id: "p1", title: "Boots", price: "£90", group: "shoes"}]
  }

  # A hero slot's words, as HTML.
  defp words(text) when is_binary(text), do: text
  defp words({:safe, _} = safe), do: Phoenix.HTML.safe_to_string(safe)

  defp words(%Phoenix.LiveView.Rendered{} = rendered),
    do: Phoenix.LiveViewTest.rendered_to_string(rendered)

  for {type, attrs} <- @full do
    test "#{type} draws its words for a visitor, and open with them typed into" do
      section = section(unquote(type), unquote(Macro.escape(attrs)))
      ctx = %{data: %{"s1" => @data[unquote(type)]}, context: %{scope: "shoes"}}

      visitor = visitor(section, ctx)

      open =
        open(section, Map.put(ctx, :choices, %{scope: Billboard.Test.Context.choices(:scope)}))

      assert visitor =~ ~s(id="section-s1")
      assert visitor =~ @words[unquote(type)]
      refute visitor =~ "contenteditable"
      assert open =~ @words[unquote(type)]
      assert open =~ "bb-inline-words"
      assert glyph(section) =~ "<span"
    end
  end

  # Text and image's photograph is 4:3 unless the site sets every
  # photograph's ratio, as Theming's Shape says.
  test "text and image draws its photograph at the site's photograph ratio" do
    section = section(:text_media, @full.text_media)

    assert visitor(section) =~ ~s|class="aspect-[var(--bb-photo-ratio,4/3)] |
  end

  # The hero draws the inside of the page's hero block, never a section
  # in `<main>` (`Billboard.Sections.Hero`).
  test "the hero draws its words into the page's hero block, for a visitor and open" do
    section =
      section(:hero, %{
        eyebrow: "Since 1999",
        heading: "Come by",
        lede: "Open *daily*.",
        photo: %{label: "The room"},
        actions: [%{kind: :visit, style: :primary}]
      })

    open = %{edit: %{open: "s1", issues: %{}, editor: %{choices: %{}}}, section: section}

    block = visitor(section)
    assert block =~ ~s(<div id="main")
    assert block =~ "Come by"
    assert block =~ "<em>daily</em>"
    refute block =~ "contenteditable"
    assert open(section) =~ "bb-inline-words"
    assert words(Hero.heading(section, %{})) == "Come by"
    refute words(Hero.heading(section, %{})) =~ "contenteditable"
    assert words(Hero.lede(section, %{})) =~ "<em>daily</em>"
    assert words(Hero.heading(section, open)) =~ "Come by"
    assert words(Hero.heading(section, open)) =~ "bb-inline-words"
    assert glyph(section) =~ "<span"
  end

  test "each draws from its placeholder too, for a visitor and open" do
    for module <- @stock, key = Billboard.Component.Info.component_key!(module), key != :hero do
      section = section(key, Billboard.Catalogue.placeholder(key))
      # Reviews, news, and prices draw nothing for a visitor until there's some.
      ctx = %{data: %{"s1" => @data[key]}}

      assert visitor(section, ctx) =~ ~s(id="section-s1")
      assert open(section, ctx) =~ "bb-inline-words"
      assert glyph(section) =~ "<span"
    end

    hero = section(:hero, Billboard.Catalogue.placeholder(:hero))
    open = %{edit: %{open: "s1", issues: %{}, editor: %{choices: %{}}}, section: hero}

    assert words(Hero.heading(hero, %{})) == "Your heading"
    assert words(Hero.heading(hero, open)) =~ "bb-inline-words"
    assert glyph(hero) =~ "<span"
  end

  test "every stock component names its renderer, declares the context it reads, and goes on every kind" do
    for module <- @stock do
      assert Billboard.Component.Info.component_renderer!(module)
      assert Billboard.Component.Info.component_kinds!(module) == :all
    end

    declared = Map.new(@stock, &{&1, Billboard.Component.Info.component_context!(&1)})

    assert declared == %{
             Components.Hero => [:bindings],
             Components.Band => [],
             Components.Points => [],
             Components.TextMedia => [],
             Components.Details => [:scope],
             Components.Reviews => [],
             Components.News => [],
             Components.Prices => [:scope]
           }
  end

  test "Two columns and Shared name their renderers, read no context, and go on every kind" do
    for module <- [Components.Columns, Components.Shared] do
      assert Billboard.Component.Info.component_renderer!(module)
      assert Billboard.Component.Info.component_kinds!(module) == :all
      assert Billboard.Component.Info.component_context!(module) == []
    end
  end
end
