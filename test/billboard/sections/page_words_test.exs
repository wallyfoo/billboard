defmodule Billboard.Sections.PageWordsTest do
  @moduledoc """
  Every stock component's words, typed into in the open section of the
  shop's page. How `Billboard.Sections.Words` draws one field's words is
  tested in `Billboard.Sections.WordsTest`.
  """
  # A case with the database, for a Shared section that reads the live
  # library.
  use Billboard.Test.DataCase, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Billboard.Catalogue
  alias Billboard.Sections
  alias Billboard.Sections.{EditorFields, Parts}
  alias Billboard.Test.Shop.{Section, Version}

  describe "every component's words, in the open section" do
    # Every stock component but Two columns and Shared, which draw other
    # sections, each with its optional parts filled, and each with only
    # what it needs, with the data it needs to draw at all. A band comes
    # twice, for the words each variant shows. The shop's own Cards and
    # Text are stand-ins with no words to type into.
    defp filled do
      head = %{eyebrow: "Our *shop*", heading: "Room for *everyone*", action: link()}

      [
        hero: %{
          eyebrow: "Welcome",
          heading: "Room for *everyone*",
          lede: "Come in.",
          actions: [link()]
        },
        band: %{eyebrow: "Visit", heading: "Come *in*", body: "Every day.", action: link()},
        band: %{
          variant: :quote_left,
          eyebrow: "Visit",
          quote: %{body: "Worth the *trip*.", name: "Ann", meta: "Owner"},
          body: "Every day."
        },
        points: %{
          head: head,
          points: for(n <- 1..3, do: %{title: "Point #{n}", body: "Words #{n}.", link: link()})
        },
        text_media: %{
          variant: :media_right,
          head: head,
          body: "Some *words*.",
          actions: [link()],
          photo: %{label: "The counter"}
        },
        details: %{head: head, items: for(n <- 1..3, do: detail(n))},
        reviews: %{head: head, note: "From *our visitors*."},
        news: %{head: head, empty: "No news yet."}
      ]
    end

    defp bare do
      [
        hero: %{heading: "x"},
        band: %{heading: "x"},
        band: %{variant: :quote_right, quote: %{body: "x"}},
        points: %{points: [%{title: "x"}, %{title: "y"}]},
        text_media: %{variant: :text_only, head: %{heading: "x"}},
        details: %{items: [detail(1)]},
        reviews: %{},
        news: %{head: %{heading: "x"}}
      ]
    end

    defp link, do: %{kind: :link, style: :text, label: "More", path: "/about"}
    defp detail(n), do: %{label: "Label #{n}", body: "Words #{n}.", only_for_group: nil}

    # Data as `Billboard.Resolver` gives it, enough for each section to draw.
    defp data(:reviews),
      do: [%{id: "r1", quote: "Lovely.", name: "Client", reviewed_on: ~D[2026-05-01]}]

    defp data(:news),
      do: [%{id: "n1", title: "Late", body: "Open *late*.", published_on: ~D[2026-09-12]}]

    defp data(_type), do: nil

    defp sections(fixtures) do
      fixtures
      |> Enum.with_index()
      |> Enum.map(fn {{type, attrs}, n} ->
        %Section{
          key: "#{type}-#{n}",
          content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
          children: []
        }
      end)
    end

    # The page with `section` alone (a hero is drawn in the header), opened.
    defp render_open(section, opts \\ []) do
      section
      |> render_page(Keyword.put_new(opts, :open, section.key))
      |> LazyHTML.from_document()
    end

    # The page with `section` alone, as HTML: as a visitor sees it, or, with
    # `open:`, in the editor with that section open.
    defp render_page(section, opts) do
      edit =
        if Keyword.has_key?(opts, :open),
          do: %{edit: %{open: opts[:open], issues: %{}, editor: nil}},
          else: %{}

      assigns = %{
        version: %Version{sections: [section]},
        data: %{section.key => data(section.content.type)},
        ctx: Map.merge(%{context: opts[:context] || %{}, state: %{}}, edit)
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
    end

    defp paths(doc, key),
      do:
        doc
        |> LazyHTML.query("[data-section='#{key}'][data-path]")
        |> LazyHTML.attribute("data-path")

    # The words paths a section shows, from its specs: every words field
    # that isn't hidden or under More, through its parts and each item of
    # its lists. An action's or a link's words aren't typed in place: the
    # button's popover edits them.
    defp shown(specs, content, at \\ []) do
      form =
        content
        |> Map.from_struct()
        |> Map.new(fn {field, value} -> {Atom.to_string(field), value} end)
        |> Phoenix.Component.to_form()

      Enum.flat_map(specs, fn {field, spec} ->
        value = Map.get(content, field)
        path = at ++ [Atom.to_string(field)]

        cond do
          EditorFields.more?(spec) or EditorFields.hidden?(form, spec) ->
            []

          Keyword.get(spec, :as, :text) in [:text, :markdown] ->
            [Enum.join(path, ".")]

          spec[:part] in [:action, :link] or is_nil(value) ->
            []

          spec[:as] == :part ->
            shown(Parts.editor_fields(spec[:part]), value, path)

          spec[:as] == :list ->
            value
            |> Enum.with_index()
            |> Enum.flat_map(fn {item, i} ->
              shown(Parts.editor_fields(spec[:part]), item, path ++ [Integer.to_string(i)])
            end)

          true ->
            []
        end
      end)
    end

    test "cover every stock component but Two columns and Shared" do
      types = Enum.map(filled(), &elem(&1, 0))

      stock =
        for entry <- Catalogue.entries(),
            String.starts_with?(inspect(entry.module), "Billboard.Components."),
            do: entry.key

      assert Enum.sort(Enum.uniq(types)) == Enum.sort(stock -- [:columns, :shared])
    end

    test "can each be typed into, once, filled or bare" do
      for section <- sections(filled()) ++ sections(bare()) do
        %{type: type, value: content} = section.content
        expected = shown(EditorFields.specs(type), content)

        assert Enum.sort(paths(render_open(section), section.key)) == Enum.sort(expected),
               "#{section.key}: #{inspect(content, pretty: true)}"
      end
    end

    # The hero's words come from its content or from what its binding
    # gives (an item page's product, or a visit), or are shortened,
    # depending on how it's set up.
    defp product,
      do: %{bindings: %{product: %{heading: "Shoes", eyebrow: "Shoes", lede: "Made *well*."}}}

    defp visit, do: %{bindings: %{visit: %{heading: "Your visit"}}}

    defp hero_cases do
      [
        {sections(hero: %{bind: :product, eyebrow: "x", heading: "x"}), product()},
        {sections(hero: %{bind: :visit, eyebrow: "x", heading: "x"}), visit()},
        {sections(hero: %{size: :auto, heading: "x", lede: String.duplicate("Long words. ", 40)}),
         %{}}
      ]
    end

    # Every fixture, filled and bare, and the hero's cases, with their
    # context.
    defp every_case do
      Enum.map(sections(filled()) ++ sections(bare()), &{&1, %{}}) ++
        for({[hero], context} <- hero_cases(), do: {hero, context})
    end

    # What the page draws of its sections, as trees: the hero's grid, and
    # what's in `<main>`. In the editor, each section's wrapper gives way
    # to what's in it, without the editor's own marks: its label and "!",
    # and the stand-in for a section that draws nothing. Text in a wrapper
    # stays, so stray words there would show; whitespace between tags
    # doesn't count.
    defp drawn(html, editor?) do
      doc = LazyHTML.from_document(html)
      tree = &LazyHTML.to_tree(&1, skip_whitespace_nodes: true)
      main = doc |> LazyHTML.query("main") |> LazyHTML.child_nodes() |> tree.()

      hero = tree.(LazyHTML.query(doc, "#page-hero > [data-hero-media]"))

      if editor?,
        do: {normal(Enum.flat_map(hero, &unmark/1)), normal(Enum.flat_map(main, &unwrap/1))},
        else: {normal(hero), normal(main)}
    end

    defp unwrap({"div", attrs, children} = node) do
      if List.keymember?(attrs, "data-edit-section", 0),
        do: children |> Enum.reject(&mark?/1) |> Enum.flat_map(&unmark/1),
        else: unmark(node)
    end

    defp unwrap(node), do: unmark(node)

    # A closed section's words sit in a span naming their path, for the
    # click that opens the section there; the span gives way to its words.
    defp unmark({"span", attrs, children}) when is_list(children) do
      if List.keymember?(attrs, "data-words-at", 0),
        do: Enum.flat_map(children, &unmark/1),
        else: [{"span", attrs, Enum.flat_map(children, &unmark/1)}]
    end

    defp unmark({tag, attrs, children}) when is_list(children),
      do: [{tag, attrs, Enum.flat_map(children, &unmark/1)}]

    defp unmark(node), do: [node]

    # Text as it reads: a run of text nodes, as a span's giving way leaves
    # them, is one, with each run of whitespace a single space, and none at
    # the start or end of an element. A space lost or gained beside an
    # inline element still shows.
    defp normal(nodes) when is_list(nodes) do
      nodes
      |> Enum.chunk_by(&is_binary/1)
      |> Enum.flat_map(fn
        [text | _] = texts when is_binary(text) ->
          [texts |> Enum.join() |> String.replace(~r/\s+/, " ")]

        nodes ->
          Enum.map(nodes, &normal/1)
      end)
      |> trim_ends()
    end

    defp normal({tag, attrs, children}) when is_list(children),
      do: {tag, attrs, normal(children)}

    defp normal(node), do: node

    defp trim_ends(nodes) do
      nodes
      |> List.update_at(0, &trim(&1, :leading))
      |> List.update_at(-1, &trim(&1, :trailing))
      |> Enum.reject(&(&1 == ""))
    end

    defp trim(text, :leading) when is_binary(text), do: String.trim_leading(text)
    defp trim(text, :trailing) when is_binary(text), do: String.trim_trailing(text)
    defp trim(node, _end), do: node

    defp mark?({_tag, attrs, _children}) do
      classes = attrs |> List.keyfind("class", 0, {"class", ""}) |> elem(1) |> String.split()
      Enum.any?(~w(bb-edit-section-tag bb-edit-section-issue bb-edit-stand-in), &(&1 in classes))
    end

    defp mark?(_text), do: false

    test "are drawn for visitors as they always were, in a closed section too" do
      # `sections_test.exs` pins what visitors see; this pins that the
      # editor's ctx changes none of it while the section isn't open.
      for {section, context} <- every_case() do
        visitor = section |> render_page(context: context) |> drawn(false)

        for open <- [nil, "elsewhere"] do
          assert section |> render_page(open: open, context: context) |> drawn(true) == visitor,
                 "#{section.key} with #{inspect(open)} open"
        end
      end
    end

    test "never draw a bare true or false, open or not" do
      for {section, context} <- every_case(),
          opts <- [[], [open: nil], [open: "elsewhere"], [open: section.key]] do
        text =
          section
          |> render_page([context: context] ++ opts)
          |> LazyHTML.from_document()
          |> LazyHTML.query("main, #page-hero")
          |> LazyHTML.text()

        refute text =~ ~r/\b(true|false)\b/, "#{section.key} #{inspect(opts)}"
      end
    end

    test "leave out empty optional words for visitors, beside the words always drawn" do
      [named, bare_quote] =
        sections(
          band: %{variant: :quote_left, quote: %{body: "x", name: "FJ"}},
          band: %{variant: :quote_left, quote: %{body: "x"}}
        )

      named = named |> render_page([]) |> LazyHTML.from_document()
      assert named |> LazyHTML.query("figcaption span") |> Enum.count() == 1
      assert named |> LazyHTML.query("figcaption") |> LazyHTML.text() |> String.trim() == "FJ"

      refute bare_quote
             |> render_page([])
             |> LazyHTML.from_document()
             |> LazyHTML.query("figcaption")
             |> Enum.any?()

      for section <- sections(bare()) do
        doc = section |> render_page([]) |> LazyHTML.from_document()
        assert doc |> LazyHTML.query(".bb-type-eyebrow") |> Enum.empty?(), section.key
      end
    end

    test "can't be typed into in a section that isn't open" do
      for section <- sections(filled()) do
        assert paths(render_open(section, open: "elsewhere"), section.key) == []
      end
    end

    test "name a detail by its place in the list, and show every one while it's open" do
      [section] =
        sections(
          details: %{
            items: [
              %{detail(1) | only_for_group: "shoes"},
              %{detail(2) | only_for_group: "hats"},
              detail(3)
            ]
          }
        )

      doc = render_open(section, context: %{scope: "hats"})

      assert Enum.sort(paths(doc, section.key)) ==
               ~w(items.0.body items.0.label items.1.body items.1.label items.2.body items.2.label)

      closed =
        section
        |> render_open(open: "elsewhere", context: %{scope: "hats"})
        |> LazyHTML.query("dt [data-words-at]")
        |> LazyHTML.attribute("data-words-at")

      assert closed == ~w(items.1.label items.2.label)
    end

    test "show an automatic hero's long lede in full" do
      long = String.duplicate("Long words here. ", 20)
      [hero] = sections(hero: %{size: :auto, heading: "x", lede: long})

      lede =
        hero
        |> render_open()
        |> LazyHTML.query("[data-path='lede']")
        |> LazyHTML.text()

      assert lede == String.trim(long)
    end

    test "leave a hero's bound words as the product or visit has them" do
      [bound] = sections(hero: %{bind: :product, eyebrow: "x", heading: "x"})

      assert paths(render_open(bound, context: product()), bound.key) == []

      [visiting] = sections(hero: %{bind: :visit, eyebrow: "x", heading: "x"})
      doc = render_open(visiting, context: visit())

      assert Enum.sort(paths(doc, visiting.key)) == ~w(eyebrow lede)
    end
  end
end
