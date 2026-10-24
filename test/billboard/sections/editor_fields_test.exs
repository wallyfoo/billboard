defmodule Billboard.Sections.EditorFieldsTest do
  @moduledoc """
  A component's editor fields as the editor reads them: found by their
  words paths, narrowed to what the site offers, and hidden by their
  settings or by the section's binding.
  """
  # The site's components and options are set in application env, which
  # every test reads.
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Billboard.Sections.EditorFields

  setup do: put_site!(components: [Billboard.Test.Faq, Billboard.Test.Cards])

  defp specs(type), do: EditorFields.specs(type)

  describe "words/2" do
    test "resolves a top-level words field" do
      assert {:ok, [:title], spec} = EditorFields.words(specs(:faq), "title")
      assert spec[:limit] == 60
    end

    test "resolves through a part" do
      specs = [head: [as: :part, part: :head]]

      assert {:ok, [:head, :heading], spec} = EditorFields.words(specs, "head.heading")
      assert spec[:limit] == 60
    end

    test "resolves through a list item" do
      assert {:ok, [:questions, 1, :body], spec} =
               EditorFields.words(specs(:faq), "questions.1.body")

      assert spec[:as] == :markdown
    end

    test "resolves a quote's words" do
      specs = [quote: [as: :part, part: :quote]]
      assert {:ok, [:quote, :name], _spec} = EditorFields.words(specs, "quote.name")
    end

    test "refuses settings, notes, unknown fields, parts, fields left out, and bad indexes" do
      assert :error = EditorFields.words(specs(:faq), "style")
      assert :error = EditorFields.words(specs(:faq), "note")
      assert :error = EditorFields.words(specs(:faq), "nope")
      assert :error = EditorFields.words(specs(:faq), "questions")
      assert :error = EditorFields.words(specs(:faq), "questions.1")
      assert :error = EditorFields.words(specs(:faq), "questions.x.body")
      assert :error = EditorFields.words(specs(:faq), "questions.1.only_for_group")
      assert :error = EditorFields.words(specs(:faq), "")
    end
  end

  describe "more?/1" do
    test "is true for words shown only in a state the editor isn't in" do
      assert EditorFields.more?(specs(:faq)[:intro])
      assert EditorFields.more?(specs(:faq)[:sign_off])
      refute EditorFields.more?(specs(:faq)[:title])
    end
  end

  describe "fields/1" do
    defp doc(html), do: LazyHTML.from_fragment(html)

    defp text(doc, selector),
      do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()

    test "draws neither a card's surface nor a photo, which the open section changes" do
      html =
        render_component(&EditorFields.fields/1,
          form: Phoenix.Component.to_form(%{"label" => "Visit"}, as: :link),
          specs: [
            surface: Billboard.Sections.Parts.editor_fields(:point)[:surface],
            photo: [as: :photo],
            label: [label: "Link words"]
          ],
          ctx: %{target: nil}
        )

      document = doc(html)
      assert document |> LazyHTML.query("input[name='link[label]']") |> Enum.count() == 1

      assert document
             |> LazyHTML.query("[name='link[surface]'], [name='link[photo]']")
             |> Enum.empty?()
    end

    test "draws a select, words with their accent hint and count, and a note" do
      html =
        render_component(&EditorFields.fields/1,
          form:
            Phoenix.Component.to_form(%{"style" => "folded", "title" => "Questions"}, as: :faq),
          specs: Keyword.take(specs(:faq), [:style, :title, :note]),
          ctx: %{target: nil, page: %{kind: :free}}
        )

      document = doc(html)

      assert text(document, "select[name='faq[style]'] option[selected]") == "Folded"
      assert document |> LazyHTML.query("select[name='faq[style]'] option") |> Enum.count() == 2
      assert text(document, "label[for='faq_title']") == "Title"
      assert html =~ "Wrap one word in asterisks to set it in italic"
      assert text(document, "#faq_title-count[phx-hook][data-limit='60']") == "9 of 60 characters"
      assert text(document, "p.border-bb-edit-warn") == "Answers fold on phones."
    end
  end

  describe "setting/1" do
    # The editor's focus rule (editor.css) rings its own UI in its blue,
    # which a setting on the controls header's blue would lose, so each
    # setting names its own ring, in the header's ink.
    test "rings a toggle in the controls header's ink" do
      html =
        render_component(&EditorFields.setting/1,
          form: Phoenix.Component.to_form(%{"open" => "true"}, as: :faq),
          field: :open,
          spec: [as: :toggle, label: "Open"],
          ctx: %{},
          error_id: "section-setting-open-error"
        )

      assert html
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(
               "input[type='checkbox'][class~='focus-visible:outline-bb-edit-on-accent']"
             )
             |> Enum.count() == 1
    end
  end

  describe "variant_glyph/1" do
    test "draws two columns at Two columns' widths" do
      for {variant, widths} <- [
            even: ["flex-1", "flex-1"],
            wide_left: ["flex-[1.6]", "flex-1"],
            wide_right: ["flex-1", "flex-[1.6]"]
          ] do
        assert EditorFields.column_widths(variant) == widths

        classes =
          render_component(&EditorFields.variant_glyph/1, variant: variant)
          |> doc()
          |> LazyHTML.query("span[aria-hidden] > *")
          |> Enum.map(&(&1 |> LazyHTML.attribute("class") |> hd()))

        assert Enum.map(classes, &(&1 |> String.split() |> Enum.find(fn c -> c in widths end))) ==
                 widths
      end
    end
  end

  describe "the stock components' fields" do
    setup do
      put_site!(
        components: [
          Billboard.Components.Hero,
          Billboard.Components.Band,
          Billboard.Components.Points,
          Billboard.Components.TextMedia,
          Billboard.Components.News
        ],
        actions: Billboard.Test.Actions,
        context: Billboard.Test.Context
      )
    end

    test "resolve their words at the top, through a part, through a list item, and in a quote" do
      assert {:ok, [:heading], spec} = EditorFields.words(specs(:hero), "heading")
      assert spec[:limit] == 42

      assert {:ok, [:head, :heading], spec} =
               EditorFields.words(specs(:text_media), "head.heading")

      assert spec[:limit] == 60

      assert {:ok, [:points, 1, :body], spec} =
               EditorFields.words(specs(:points), "points.1.body")

      assert spec[:as] == :markdown
      assert {:ok, [:quote, :name], _spec} = EditorFields.words(specs(:band), "quote.name")
    end

    test "refuse settings, a binding and its note, a part, a link in an item, and bad indexes" do
      assert :error = EditorFields.words(specs(:hero), "variant")
      assert :error = EditorFields.words(specs(:hero), "bound")
      assert :error = EditorFields.words(specs(:hero), "bind")
      assert :error = EditorFields.words(specs(:text_media), "head")
      assert :error = EditorFields.words(specs(:points), "points.1")
      assert :error = EditorFields.words(specs(:points), "points.x.body")
      assert :error = EditorFields.words(specs(:points), "points.1.link")
      assert :error = EditorFields.words(specs(:hero), "")
    end

    test "offer news's words for no news under More, and a hero's heading in place" do
      assert EditorFields.more?(specs(:news)[:empty])
      refute EditorFields.more?(specs(:hero)[:heading])
    end
  end

  describe "narrowed/1" do
    test "keeps a select to the options the site offers" do
      put_site!(options: [cards: [look: [:rows], columns: [2, 3]]])
      narrowed = EditorFields.narrowed(:cards)

      assert narrowed[:look][:options] == [{"Rows", :rows}]
      assert narrowed[:columns][:options] == [{"Two", 2}, {"Three", 3}]
    end

    test "keeps a list to the site's range, three or four" do
      put_site!(options: [cards: [items: 1..3]])
      assert EditorFields.narrowed(:cards)[:items][:max] == 3

      put_site!(options: [cards: [items: 1..4]])
      assert EditorFields.narrowed(:cards)[:items] == specs(:cards)[:items]
    end

    test "keeps the fields, in the component's order" do
      put_site!(options: [cards: [look: [:rows], items: 1..3]])

      assert Keyword.keys(EditorFields.narrowed(:cards)) == Keyword.keys(specs(:cards))
      assert EditorFields.narrowed(:faq) == specs(:faq)
    end

    test "lists a select's options in the component's order, not the site's" do
      put_site!(options: [cards: [look: [:cards, :rows]]])

      assert EditorFields.narrowed(:cards)[:look][:options] == [
               {"Rows", :rows},
               {"Cards", :cards}
             ]
    end

    test "lowers a list's max to the most the site offers" do
      put_site!(options: [cards: [items: 1..2]])

      assert EditorFields.narrowed(:cards)[:items][:max] == 2
      assert EditorFields.narrowed(:cards)[:items][:min] == 1
    end

    test "raises a list's min to the fewest the site offers" do
      put_site!(options: [cards: [items: 2..3]])

      assert EditorFields.narrowed(:cards)[:items][:min] == 2
      assert EditorFields.narrowed(:cards)[:items][:max] == 3
    end

    test "leaves a list the site doesn't name as the component has it" do
      assert EditorFields.narrowed(:cards)[:items] == specs(:cards)[:items]
    end

    test "keeps variants to the layouts the site offers, in the component's order" do
      put_site!(options: [cards: [variant: [:media_right, :text_only]]])

      assert EditorFields.narrowed(:cards)[:variant][:options] == [:text_only, :media_right]
    end

    test "leaves variants the site doesn't name as the component has them" do
      assert EditorFields.narrowed(:cards)[:variant] == specs(:cards)[:variant]
    end
  end

  describe "the section's binding" do
    test "hides a field while the section's binding replaces its words" do
      put_site!(components: [Billboard.Test.Faq], context: Billboard.Test.Context)
      form = %{bind: %{value: "product"}}
      plain = %{bind: %{value: :none}}

      assert EditorFields.hidden?(form, bound: :hide, as: :text)
      refute EditorFields.hidden?(plain, bound: :hide, as: :text)
    end

    test "makes a binding's note the note of the binding the form names" do
      put_site!(components: [Billboard.Test.Faq], context: Billboard.Test.Context)
      specs = [bound: [as: :binding_note], title: [as: :text]]

      assert [
               bound: [
                 as: :note,
                 text: "The heading comes from the product.",
                 link: {"Open the products", "/admin/products"}
               ],
               title: [as: :text]
             ] = EditorFields.binding_notes(specs, %{bind: %{value: :product}})

      assert [title: [as: :text]] = EditorFields.binding_notes(specs, %{bind: %{value: :visit}})
    end
  end

  defmodule Shelf do
    @moduledoc "A site's own part that picks from a set of choices."
    use Billboard.Part

    editor do
      field :aisle, as: :choice, from: :aisles, label: "Aisle"
    end

    attributes do
      uuid_primary_key :id
      attribute :aisle, :string, public?: true
    end

    actions do
      defaults [:read, :destroy, create: :*, update: :*]
    end
  end

  defmodule Shelves do
    @moduledoc "A component whose list holds the site's own part."
    use Billboard.Component

    component do
      key :shelves
      label "Shelves"
      hint "Shelves, each in an aisle."
      category :content
      parts :shelves, Shelf
    end

    editor do
      field :shelves, as: :list, part: Shelf, item_label: "shelf"
    end
  end

  test "names every set of choices the site's components and parts pick from" do
    put_site!(components: [Billboard.Test.Faq])
    assert EditorFields.choice_names() == [:scope]

    put_site!(components: [Billboard.Test.Faq, Shelves])
    assert EditorFields.choice_names() == [:scope, :aisles]
  end

  describe "hidden_at?/3" do
    # A band's quote, which its heading layout leaves out, and a list of
    # details, read on forms built from params, as the editor's are.
    @specs [
      variant: [as: :variants, options: [:heading, :quote_left]],
      quote: [as: :part, part: :quote, hide_when: [variant: [:heading]]],
      items: [as: :list, part: :detail]
    ]

    defp content(variant) do
      Phoenix.Component.to_form(
        %{
          "variant" => variant,
          "quote" => %{"body" => "Hair over years."},
          "items" => [%{"label" => "Parking", "body" => "Round the back."}]
        },
        as: :content
      )
    end

    test "leaves out words inside a part its section's layout leaves out" do
      assert EditorFields.hidden_at?(content("heading"), @specs, [:quote, :body])
      refute EditorFields.hidden_at?(content("quote_left"), @specs, [:quote, :body])
    end

    test "reads a list item's fields on the item's own form" do
      refute EditorFields.hidden_at?(content("heading"), @specs, [:items, 0, :body])
    end

    test "leaves out a field the specs don't name, or a holder the form hasn't got" do
      assert EditorFields.hidden_at?(content("quote_left"), @specs, [:nope])
      assert EditorFields.hidden_at?(content("quote_left"), @specs, [:items, 3, :body])
      assert EditorFields.hidden_at?(content("quote_left"), @specs, [])
    end
  end
end
