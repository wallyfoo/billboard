defmodule Billboard.Sections.HeroTest do
  @moduledoc """
  The hero, slot by slot, as the page asks for each: its own words, or a
  binding's, which stand in for its own where it gives them.
  """
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Phoenix.LiveViewTest, only: [render_component: 2, rendered_to_string: 1]

  alias Billboard.Components
  alias Billboard.Sections.{Blocks, Hero}
  alias Billboard.Test.Render

  setup do
    put_site!(
      components: [Components.Hero],
      actions: Billboard.Test.Actions,
      context: Billboard.Test.Context
    )
  end

  @product %{
    heading: "Shoes",
    eyebrow: "Aisle 3",
    lede: "Every *size*.",
    photo_label: "Laces",
    seed: "shoes"
  }

  defp hero(attrs), do: Render.section(:hero, attrs)

  defp update(component, attrs),
    do: component |> Ash.Changeset.for_update(:update, attrs) |> Ash.update()

  defp product(binding \\ %{}),
    do: %{context: %{bindings: %{product: Map.merge(@product, binding)}}}

  # The section open in the editor, on a page with `context`.
  defp open(section, context \\ %{}),
    do: %{
      edit: %{open: section.key, issues: %{}, editor: %{choices: %{}}},
      section: section,
      context: context
    }

  # A slot's words, as HTML.
  defp html(nil), do: ""
  defp html(text) when is_binary(text), do: text
  defp html({:safe, _} = safe), do: Phoenix.HTML.safe_to_string(safe)
  defp html(%Phoenix.LiveView.Rendered{} = rendered), do: rendered_to_string(rendered)

  defp doc(html), do: LazyHTML.from_fragment(html)

  defp has?(html, selector), do: html |> doc() |> LazyHTML.query(selector) |> Enum.count() > 0

  defp text(html, selector), do: html |> doc() |> LazyHTML.query(selector) |> LazyHTML.text()

  defp media_slot(section, ctx \\ %{}),
    do: render_component(&Hero.media_slot/1, section: section, ctx: ctx)

  describe "the hero" do
    test "sets its heading from its Markdown, with the photograph on the right by default" do
      section = hero(%{heading: "The *shop*", photo: %{label: "The room"}})

      assert html(Hero.heading(section, %{})) == "The <em>shop</em>"
      assert Hero.media(section, %{}) == "right"
      assert has?(media_slot(section), "figure .aspect-\\[4\\/3\\]")
      assert String.trim(text(media_slot(section), "figure span.bb-type-label")) == "The room"
    end

    test "image left mirrors the hero, and text only drops the photograph" do
      assert Hero.media(hero(%{heading: "x", variant: :media_left, photo: %{label: "p"}}), %{}) ==
               "left"

      assert Hero.media(hero(%{heading: "x", variant: :text_only, photo: %{label: "p"}}), %{}) ==
               "none"
    end

    test "a hero with no photograph has none to show, and no hero has no slots" do
      assert Hero.media(hero(%{heading: "x"}), %{}) == "none"
      assert Hero.media(nil, %{}) == "none"
      assert Hero.heading(nil, %{}) == nil
      assert Hero.size(nil, %{}) == "h1"
      refute Hero.actions?(nil)
    end

    test "a new hero starts text only, as it has no photograph to show yet" do
      new = hero(Billboard.Catalogue.placeholder(:hero))

      assert new.content.value.variant == :text_only
      assert Hero.media(new, %{}) == "none"
    end

    test "automatic size drops to h1 when the heading runs long" do
      long = String.duplicate("word ", 12)

      assert Hero.size(hero(%{heading: "Short", size: :auto}), %{}) == "display"
      assert Hero.size(hero(%{heading: long, size: :auto}), %{}) == "h1"
      assert Hero.size(hero(%{heading: long, size: :display}), %{}) == "display"
      assert Hero.size(hero(%{heading: "Short"}), %{}) == "h1"
    end

    test "the eyebrow and lede render from the content" do
      section = hero(%{eyebrow: "Training", heading: "x", lede: "Taught *here*."})

      assert html(Hero.eyebrow(section, %{})) == "Training"
      assert has?(html(Hero.lede(section, %{})), "em")
      assert Hero.eyebrow(hero(%{heading: "x"}), %{}) == nil
      assert Hero.lede(hero(%{heading: "x"}), %{}) == nil
    end

    test "an automatic hero shortens a long lede, past its limit" do
      lede = String.duplicate("word ", 60)
      shortened = html(Hero.lede(hero(%{heading: "x", size: :auto, lede: lede}), %{}))

      assert String.length(String.trim(shortened)) <= Components.Hero.lede_limit()
      assert html(Hero.lede(hero(%{heading: "x", lede: lede}), %{})) =~ String.trim(lede)
    end

    test "the browser title is the heading without its Markdown, or nil with no hero" do
      version = %{sections: [hero(%{heading: "The *shop*"})]}

      assert Hero.title(version) == "The shop"
      assert Hero.title(%{sections: []}) == nil
    end

    test "actions sit straight in the action row, in order, with the hero's ids" do
      section =
        hero(%{
          heading: "x",
          actions: [
            %{kind: :visit, style: :primary},
            %{kind: :link, style: :secondary, label: "Prices", path: "/prices"},
            %{kind: :call}
          ]
        })

      html = render_component(&Hero.actions/1, section: section, ctx: %{})

      assert has?(html, "a#hero-visit:first-child[href='/visit']")
      assert has?(html, "a[href='/prices']")
      assert has?(html, "a.test-call:last-child")
      assert Hero.actions?(section)
      refute Hero.actions?(hero(%{heading: "x"}))
    end

    test "open, its words are typed into, empty ones too, and it offers to add an action" do
      section = hero(%{heading: "x"})
      ctx = open(section)

      assert html(Hero.heading(section, ctx)) =~ "contenteditable"
      assert html(Hero.eyebrow(section, ctx)) =~ "Eyebrow (optional)"
      assert html(Hero.lede(section, ctx)) =~ "Opening lines (optional)"
      assert Hero.actions?(section, ctx)

      assert has?(
               render_component(&Hero.actions/1, section: section, ctx: ctx),
               "button#section-add-button-actions"
             )
    end

    test "refuses a binding the site doesn't offer, checked when it changes" do
      assert {:error, error} =
               Billboard.Component.build(:hero, %{heading: "Hi", bind: :elsewhere})

      assert Exception.message(error) =~ "this site doesn't offer “elsewhere” here"

      assert {:ok, %{bind: :product} = stored} =
               Billboard.Component.build(:hero, %{heading: "Hi", bind: :product})

      put_site!(context: nil)

      assert {:ok, %{bind: :product, heading: "Hello"}} = update(stored, %{heading: "Hello"})
      assert {:error, error} = update(stored, %{bind: :visit})
      assert Exception.message(error) =~ "this site doesn't offer “visit” here"
    end
  end

  describe "a hero bound to a product" do
    defp product_hero(attrs \\ %{}),
      do: hero(Map.merge(%{bind: :product, photo: %{label: "Hands working"}}, attrs))

    test "takes its heading, eyebrow, and lede from the binding" do
      section = product_hero()

      assert Hero.heading(section, product()) == "Shoes"
      assert html(Hero.eyebrow(section, product())) == "Aisle 3"
      assert has?(html(Hero.lede(section, product())), "em")
      assert Hero.title(%{sections: [section]}, product()) == "Shoes"
    end

    test "uses the binding's photo label, else its own, seeded by the binding" do
      section = product_hero()
      seeded = render_component(&Blocks.voronoi_noise/1, seed: "shoes")

      assert String.trim(text(media_slot(section, product()), "figure span.bb-type-label")) ==
               "Laces"

      assert media_slot(section, product()) =~ seeded

      unlabelled = media_slot(section, product(%{photo_label: nil}))
      assert String.trim(text(unlabelled, "figure span.bb-type-label")) == "Hands working"
    end

    test "drops the lede when the binding has none" do
      assert Hero.lede(product_hero(), product(%{lede: nil})) == nil
    end

    test "draws its own words on a page that hasn't got the binding" do
      section = product_hero(%{heading: "Our *shoes*"})

      assert html(Hero.heading(section, %{context: %{}})) == "Our <em>shoes</em>"
    end

    test "open, its own words aren't typed into, since the binding replaces them" do
      section = product_hero(%{heading: "Mine", eyebrow: "Own"})
      ctx = open(section, %{})

      refute html(Hero.heading(section, ctx)) =~ "contenteditable"
      refute html(Hero.eyebrow(section, ctx)) =~ "contenteditable"
      refute html(Hero.lede(section, ctx)) =~ "contenteditable"
    end
  end

  describe "a hero bound to a visit" do
    defp visit_hero,
      do: hero(%{variant: :text_only, bind: :visit, eyebrow: "Visiting", heading: "Come by"})

    test "takes its heading from the visit, when there is one" do
      assert Hero.heading(visit_hero(), %{context: %{bindings: %{visit: %{heading: "A fitting"}}}}) ==
               "A fitting"

      assert html(Hero.heading(visit_hero(), %{context: %{bindings: %{visit: nil}}})) ==
               "Come by"
    end

    test "keeps its own eyebrow, which the visit doesn't give" do
      ctx = %{context: %{bindings: %{visit: %{heading: "A fitting"}}}}
      assert html(Hero.eyebrow(visit_hero(), ctx)) == "Visiting"
    end

    test "open, its own words are typed into, since the visit doesn't replace them" do
      section = visit_hero()
      assert html(Hero.eyebrow(section, open(section))) =~ "contenteditable"
    end
  end
end
