defmodule Billboard.SectionsTest do
  @moduledoc """
  The page (`Billboard.Sections.page/1`), drawn in the shop's layout
  (`Billboard.Test.Layout`): the hero block, the sections in order on
  their surfaces, and the editor's wrappers and stand-ins.
  """
  use Billboard.Test.DataCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Billboard.{Catalogue, Components, Sections}
  alias Billboard.Test.Shop.{Section, Version}

  defp s(type, attrs, opts \\ []) do
    %Section{
      key: opts[:key] || "#{type}",
      anchor: opts[:anchor],
      surface: opts[:surface],
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: opts[:children] || []
    }
  end

  defp render_page(sections, ctx \\ %{}, site \\ %{}, opts \\ []) do
    assigns = %{
      version: %Version{sections: sections},
      ctx: ctx,
      site: Map.merge(%{name: "The shop"}, site),
      data: opts[:data] || %{}
    }

    ~H"""
    <Sections.page
      version={@version}
      data={@data}
      ctx={@ctx}
      flash={%{}}
      site={@site}
      current_path="/"
    />
    """
    |> rendered_to_string()
    |> LazyHTML.from_document()
  end

  defp has?(doc, selector), do: LazyHTML.query(doc, selector) |> Enum.count() > 0

  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text()

  defp attribute(doc, selector, name),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.attribute(name) |> List.first()

  describe "the registry" do
    test "an anchor is the section's own, or one made from its key" do
      assert Sections.anchor(%{anchor: "in-practice", key: "points"}) == "in-practice"
      assert Sections.anchor(%{anchor: nil, key: "points"}) == "section-points"
    end
  end

  describe "glyphs" do
    defp glyph(section, library \\ nil) do
      assigns = %{section: section, library: library}

      ~H"""
      <Sections.glyph section={@section} library={@library} />
      """
      |> rendered_to_string()
      |> LazyHTML.from_fragment()
    end

    test "every section of every page draws one, naming its component" do
      for page <- Billboard.Directory.pages(),
          section <- Billboard.Pages.page_for(page.pattern).sections do
        type = Atom.to_string(section.content.type)

        assert [^type] =
                 section |> glyph() |> LazyHTML.attribute("data-component") |> Enum.take(1)
      end
    end

    test "a mirrored section's glyph names its variant" do
      for variant <- ~w(text_only media_left media_right)a do
        html =
          glyph(
            s(:text_media, %{
              head: %{heading: "Hi"},
              photo: %{label: "The counter"},
              variant: variant
            })
          )

        assert LazyHTML.attribute(html, "data-variant") == [Atom.to_string(variant)]
      end
    end

    test "a shared section draws its library section, or an outline once it has gone" do
      band = s(:band, %{heading: "Visit the shop"}, key: "promo")
      shared = s(:shared, %{key: "promo"})

      assert shared
             |> glyph(%{"promo" => band})
             |> LazyHTML.query("[data-component='band']")
             |> Enum.count() == 1

      assert shared |> glyph(%{}) |> LazyHTML.query("[data-component='band']") |> Enum.count() ==
               0
    end

    test "two columns draw their columns' glyphs side by side" do
      text = s(:text, %{body: "Words"})
      doc = glyph(s(:columns, %{variant: :wide_left}, children: [text, text]))

      assert doc |> LazyHTML.query("[data-component='text']") |> Enum.count() == 2
      assert has?(doc, "[data-variant='wide_left'] .flex-\\[1\\.6\\] [data-component='text']")
    end
  end

  describe "the hero" do
    test "sits in the layout's hero slot, after its header, with the sections in main" do
      doc = render_page([s(:hero, %{heading: "Hi"}), s(:text, %{body: "Come in."}, key: "w")])

      assert has?(doc, "#shop-header + .bb-surface-loud > #page-hero")
      assert has?(doc, ".bb-surface-loud + main > #section-w")
      assert has?(doc, "main + #shop-footer")
      assert text(doc, "#shop-header") == "The shop"
    end

    test "fills the header block, with the photograph on the right by default" do
      doc = render_page([s(:hero, %{heading: "The *shop*", photo: %{label: "The room"}})])

      assert has?(doc, ".bb-surface-loud #page-hero h1.bb-type-title.text-bb-title em")
      assert has?(doc, "#page-hero [data-hero-media='right']")
      assert has?(doc, "#page-hero figure .aspect-\\[4\\/3\\]")
      assert has?(doc, "#page-hero [data-hero-media='right'] > div:not([class]) > figure")
    end

    test "image left mirrors the hero, and text only drops the photograph" do
      left = render_page([s(:hero, %{heading: "x", variant: :media_left, photo: %{label: "p"}})])
      assert has?(left, "#page-hero [data-hero-media='left']")
      assert has?(left, "#page-hero [data-hero-media='left'] > div.md\\:order-first figure")

      assert has?(
               left,
               "#page-hero [data-hero-media='left'] > #main:not(.md\\:order-first)"
             )

      text_only = render_page([s(:hero, %{heading: "x", variant: :text_only})])
      refute has?(text_only, "#page-hero figure")
      assert has?(text_only, "#page-hero [data-hero-media='none']")
    end

    test "a hero with no photograph has none to show" do
      refute has?(render_page([s(:hero, %{heading: "x"})]), "#page-hero figure")
    end

    test "automatic size drops to h1 when the heading runs long" do
      long = String.duplicate("word ", 12)
      assert has?(render_page([s(:hero, %{heading: "Short", size: :auto})]), "h1.bb-type-display")
      assert has?(render_page([s(:hero, %{heading: long, size: :auto})]), "h1.bb-type-title")
      assert has?(render_page([s(:hero, %{heading: long, size: :display})]), "h1.bb-type-display")
    end

    test "the eyebrow and lede render from the content" do
      doc = render_page([s(:hero, %{eyebrow: "Opening", heading: "x", lede: "Made *here*."})])

      assert text(doc, "#page-hero p.bb-type-eyebrow") == "Opening"
      assert has?(doc, "#page-hero div.bb-type-lead.text-bb-ink em")
    end

    test "an automatic hero shortens a long lede" do
      lede = String.duplicate("word ", 60)
      doc = render_page([s(:hero, %{heading: "x", size: :auto, lede: lede})])

      assert String.length(String.trim(text(doc, "#page-hero div.bb-type-lead"))) <=
               Components.Hero.lede_limit()
    end

    test "the hero's visit action keeps its id" do
      doc = render_page([s(:hero, %{heading: "x", actions: [%{kind: :visit, style: :primary}]})])
      assert has?(doc, "#hero-visit[href='/visit']")
      assert text(doc, "#hero-visit") =~ "Visit"
    end

    test "actions sit straight in the hero's action row, in order" do
      actions = [
        %{kind: :visit, style: :primary, label: "Visit"},
        %{kind: :link, style: :secondary, label: "About us", path: "/about"},
        %{kind: :call}
      ]

      doc = render_page([s(:hero, %{heading: "x", actions: actions})])

      assert has?(doc, "#main > div.mt-12 > a#hero-visit:first-child")
      assert has?(doc, "#main > div.mt-12 > a[href='/about']")
      assert has?(doc, "#main > div.mt-12 > a.test-call:last-child")
    end

    test "a call action draws from the site's own data" do
      hero = s(:hero, %{heading: "x", actions: [%{kind: :call}]})

      doc = render_page([hero], %{}, %{phone: "01151234567"})
      assert attribute(doc, "#main > div.mt-12 > a", "href") == "tel:01151234567"
    end

    test "with no hero, the header block has an empty heading" do
      doc = render_page([])
      assert has?(doc, "#page-hero h1")
      refute has?(doc, "#page-hero figure")
    end

    test "a version with no hero draws the heading and lede it's given" do
      assigns = %{version: %Version{sections: []}}

      doc =
        ~H"""
        <Sections.page
          version={@version}
          flash={%{}}
          site={%{name: "The shop"}}
          heading="Shared sections"
          lede="On every page."
        />
        """
        |> rendered_to_string()
        |> LazyHTML.from_document()

      assert text(doc, "#page-hero h1") =~ "Shared sections"
      assert text(doc, "#page-hero div.bb-type-lead") =~ "On every page."
    end
  end

  describe "change tracking through the layout" do
    alias Phoenix.LiveView.{Diff, Socket}

    defp version_with_hero(heading),
      do: %Version{sections: [s(:hero, %{heading: heading, lede: "Come in."}, key: "hero")]}

    defp page_assigns(heading) do
      %{
        version: version_with_hero(heading),
        site: %{name: "The shop"},
        flash: %{},
        data: %{},
        library: nil,
        ctx: %{},
        current_path: "/",
        editing: false,
        heading: nil,
        lede: nil
      }
    end

    # The page drawn once, then again with `changed`, as a LiveView sends
    # it: the second diff holds only what changed.
    defp diffs(first, second, changed) do
      socket = %Socket{endpoint: Billboard.Test.Endpoint}
      render = &Sections.page/1

      {_full, prints, components} =
        Diff.render(
          socket,
          render.(Map.put(first, :__changed__, nil)),
          Diff.new_fingerprints(),
          Diff.new_components()
        )

      {diff, _prints, _components} =
        Diff.render(socket, render.(Map.put(second, :__changed__, changed)), prints, components)

      inspect(diff, limit: :infinity, printable_limit: :infinity)
    end

    # It fails if the page hands the layout assigns built afresh, without
    # what changed: the layout's header is then sent again.
    test "a change to the hero's heading sends the heading alone, not the layout" do
      diff = diffs(page_assigns("First"), page_assigns("Second"), %{version: true})

      assert diff =~ "Second"
      refute diff =~ "The shop"
    end

    test "a change to the site's data reaches the layout" do
      diff =
        diffs(
          page_assigns("First"),
          %{page_assigns("First") | site: %{name: "The new shop"}},
          %{site: true}
        )

      assert diff =~ "The new shop"
    end
  end

  describe "sections written in the editor" do
    test "a quote band puts the quote left by default, and right when mirrored" do
      q = %{variant: :quote_left, quote: %{body: "Worth the trip.", name: "Ann", meta: "Owner"}}

      assert has?(
               render_page([hero(), s(:points, pts()), s(:band, q, anchor: "statement")]),
               "#statement.bb-surface-loud [data-quote-side='left'] blockquote"
             )

      assert has?(
               render_page([
                 hero(),
                 s(:points, pts()),
                 s(:band, %{q | variant: :quote_right}, anchor: "statement")
               ]),
               "#statement [data-quote-side='right']"
             )
    end

    test "points use h3 under a section head, and h2 without one" do
      assert has?(
               render_page([
                 hero(),
                 s(:points, Map.put(pts(), :head, %{heading: "In practice"}), anchor: "p")
               ]),
               "#p h3"
             )

      assert has?(render_page([hero(), s(:points, pts(), anchor: "p")]), "#p h2")
    end

    test "points are rows by default, each under a hairline" do
      two = %{points: [%{title: "Late"}, %{title: "Sunday", surface: nil}]}
      doc = render_page([hero(), s(:points, two, anchor: "p")])

      assert Billboard.Component.build!(:points, two).look == :rows

      assert [_, _] =
               LazyHTML.query(
                 doc,
                 "#p .bb-point.bb-rule-top.pt-\\[var\\(--bb-rule-gap\\,1\\.5rem\\)\\]"
               )
               |> Enum.to_list()

      refute has?(doc, "#p .bb-card")
      refute has?(doc, "#p [data-surface]")
    end

    test "a site that offers cards no surface can't save one" do
      assert {:error, %Ash.Error.Invalid{}} =
               Billboard.Component.build(:points, %{points: [%{title: "Late", surface: "plain"}]})
    end

    test "text and image mirrors its photograph" do
      attrs = %{variant: :media_left, head: %{heading: "Our range"}, photo: %{label: "Shelves"}}

      assert has?(
               render_page([hero(), s(:text_media, attrs, anchor: "t")]),
               "#t [data-media='left'] figure"
             )
    end

    test "a detail limited to a scope only shows on that scope's page" do
      items = [%{label: "Sizing", body: "Runs small.", only_for_group: "shoes"}]

      page = fn scope ->
        render_page([hero(), s(:details, %{items: items}, anchor: "d")], %{
          context: %{scope: scope}
        })
      end

      assert has?(page.("shoes"), "#d dt")
      refute has?(page.("hats"), "#d dt")
    end

    test "two columns lay their sections side by side, wide on the left when asked" do
      cols =
        s(:columns, %{variant: :wide_left},
          anchor: "c",
          children: [s(:details, det(), key: "one"), s(:details, det(), key: "two")]
        )

      assert has?(render_page([hero(), cols]), "#c[data-columns='wide_left'] > div > *")
    end

    test "a shared section renders the library's section" do
      assert has?(
               render_page([hero(), s(:points, pts()), s(:shared, %{key: "promo"})]),
               ".bb-surface-loud h2"
             )
    end

    test "a shared section keeps the library section's anchor" do
      doc = render_page([hero(), s(:points, pts()), s(:shared, %{key: "promo"})])
      assert has?(doc, "main > #promo.bb-surface-loud")
    end

    test "a shared section whose key has left the library renders nothing" do
      doc = render_page([hero(), s(:shared, %{key: "gone"}, anchor: "gone")])
      refute has?(doc, "main > *")
    end

    test "sections in two columns leave the margin and padding to the columns" do
      cols =
        s(:columns, %{variant: :even},
          anchor: "c",
          children: [
            s(:details, det(), key: "one", anchor: "one"),
            s(:details, det(), key: "two", anchor: "two")
          ]
        )

      doc = render_page([hero(), cols, s(:details, det(), key: "three", anchor: "three")])

      assert has?(doc, "#c.bb-wrap.bb-section-pad")
      assert has?(doc, "#c > div > #one.page-section.bb-surface-plain")
      refute has?(doc, "#one.bb-wrap")
      refute has?(doc, "#one.bb-section-pad")
      refute has?(doc, "#two.bb-wrap")
      refute has?(doc, "#two.bb-section-pad")
      assert has?(doc, "#three.bb-wrap.bb-section-pad")
    end

    test "narrow details keep to a reading width, and standard ones don't" do
      narrow = render_page([hero(), s(:details, Map.put(det(), :width, :narrow), anchor: "d")])
      assert has?(narrow, "#d > div.max-w-\\[35rem\\] > dl dt")

      standard = render_page([hero(), s(:details, det(), anchor: "d")])
      assert has?(standard, "#d > dl dt")
      refute has?(standard, "#d .max-w-\\[35rem\\]")
    end

    test "details with no head and nothing to show render nothing" do
      items = [%{label: "Sizing", body: "Runs small.", only_for_group: "shoes"}]
      doc = render_page([hero(), s(:details, %{items: items}, anchor: "d")])
      refute has?(doc, "#d")

      headed = s(:details, %{head: %{heading: "Before you buy"}, items: items}, anchor: "d")
      doc = render_page([hero(), headed])
      assert has?(doc, "#d h2")
      refute has?(doc, "#d dl")
    end

    test "a point's link is a text link" do
      link = %{kind: :link, style: :primary, label: "Read more", path: "/about"}
      points = %{points: [%{title: "Step-free", link: link}]}
      doc = render_page([hero(), s(:points, points, anchor: "p")])

      assert has?(doc, "#p a.bb-link.bb-type-label.mt-3[href='/about']")
      refute has?(doc, "#p a.bb-button")
    end

    test "text only has no photograph" do
      attrs = %{variant: :text_only, head: %{heading: "Our range"}, photo: %{label: "Shelves"}}
      doc = render_page([hero(), s(:text_media, attrs, anchor: "t")])

      assert has?(doc, "#t h2")
      refute has?(doc, "#t figure")
      refute has?(doc, "#t [data-media]")
    end
  end

  defp hero, do: s(:hero, %{heading: "x"})
  defp pts, do: %{points: [%{title: "Late on Thursdays", body: "Open till eight."}]}
  defp det, do: %{items: [%{label: "Where", body: "On the high street."}]}

  describe "the body" do
    test "sections after the hero render in order, with their anchors" do
      doc =
        render_page([
          s(:hero, %{heading: "x"}),
          s(:points, %{points: [%{title: "Late"}]}, anchor: "in-practice"),
          s(:text, %{body: "Come in."}, anchor: "welcome")
        ])

      assert has?(doc, "main > #in-practice + #welcome")
    end
  end

  defp band(anchor), do: s(:band, %{heading: "Visit the shop"}, key: anchor, anchor: anchor)
  defp points(anchor, opts \\ []), do: s(:points, pts(), [key: anchor, anchor: anchor] ++ opts)

  # Reviews with none published, which draw nothing.
  defp no_reviews(key), do: s(:reviews, %{}, key: key)

  # The page editor's canvas, with a place to add a section between every
  # two, or without them, as a fixed page draws it.
  defp edit_ctx(add? \\ true), do: %{edit: %{open: nil, add: if(add?, do: %{at: nil})}}

  describe "surfaces" do
    test "a plain section names its surface, and carries its class" do
      doc = render_page([hero(), points("p")])
      assert has?(doc, "main > #p.page-section.bb-surface-plain[data-surface='plain']")
    end

    test "a band carries its surface's class" do
      doc = render_page([hero(), points("p"), band("b")])
      assert has?(doc, "main > #b.page-section.bb-surface-loud[data-surface='loud']")
      refute has?(doc, "#b.bb-surface-plain")
    end

    test "the second of two plain sections in a row is joined" do
      doc = render_page([hero(), points("a"), s(:details, det(), key: "b", anchor: "b")])

      refute has?(doc, "#a.bb-joined")
      assert has?(doc, "#b.bb-joined")
    end

    test "a section on another surface than the one before it isn't joined" do
      doc = render_page([hero(), points("a"), band("b"), points("c")])

      refute has?(doc, "#b.bb-joined")
      refute has?(doc, "#c.bb-joined")
    end

    test "the first section isn't joined, after the hero or with none" do
      refute has?(render_page([hero(), points("a")]), ".bb-joined")
      refute has?(render_page([points("a")]), ".bb-joined")
    end

    test "two bands in a row both keep their padding, since each stands alone" do
      doc = render_page([hero(), points("a"), band("b"), band("c")])

      assert has?(doc, "#c.bb-surface-loud")
      refute has?(doc, ".bb-joined")
    end

    test "bands that meet across a section that draws nothing keep their padding" do
      doc = render_page([hero(), points("a"), band("b"), no_reviews("r"), band("c")])

      refute has?(doc, "#section-r")
      refute has?(doc, ".bb-joined")
    end

    test "on the library page, with no hero, two bands keep their padding and plain joins" do
      shared = s(:shared, %{key: "promo"}, key: "s1")
      library = %{"promo" => band("promo")}

      doc =
        render_page(
          [band("a"), shared, points("b"), points("c")],
          %{shared: library}
        )

      refute has?(doc, "#a.bb-joined")
      refute has?(doc, "#promo.bb-joined")
      refute has?(doc, "#b.bb-joined")
      assert has?(doc, "#c.bb-joined")
    end

    test "a section that draws nothing leaves its neighbours joined" do
      doc = render_page([hero(), points("a"), no_reviews("r"), points("c")])

      refute has?(doc, "#section-r")
      assert has?(doc, "#c.bb-joined")
    end

    test "a section whose stored surface isn't offered is drawn on its kind's default" do
      doc = render_page([hero(), points("a", surface: "loud"), points("b", surface: "lilac")])

      assert has?(doc, "#a.bb-surface-plain[data-surface='plain']")
      refute has?(doc, "#a.bb-surface-loud")
      assert has?(doc, "#b.bb-surface-plain.bb-joined")
    end

    test "columns' children draw on their parent's surface, and never join" do
      cols =
        s(:columns, %{variant: :even},
          key: "c",
          anchor: "c",
          children: [
            s(:details, det(), key: "one", anchor: "one"),
            s(:details, det(), key: "two", anchor: "two")
          ]
        )

      doc = render_page([hero(), points("a"), cols])

      assert has?(doc, "#c.page-section.bb-surface-plain.bb-joined[data-surface='plain']")
      assert has?(doc, "#c > div > #one.page-section.bb-surface-plain[data-surface='plain']")
      assert has?(doc, "#c > div > #two.bb-surface-plain")
      refute has?(doc, "#c .bb-joined")
    end

    test "a shared section draws on its library section's surface" do
      library = %{"promo" => band("promo"), "promise" => points("promise")}

      doc =
        render_page(
          [
            hero(),
            points("a"),
            s(:shared, %{key: "promo"}, key: "s1"),
            s(:shared, %{key: "promise"}, key: "s2"),
            points("c")
          ],
          %{shared: library}
        )

      assert has?(doc, "main > #promo.bb-surface-loud[data-surface='loud']")
      refute has?(doc, "#promo.bb-joined")
      assert has?(doc, "main > #promise.bb-surface-plain")
      refute has?(doc, "#promise.bb-joined")
      assert has?(doc, "#c.bb-joined")
    end

    test "what's on keeps its deeper bottom padding when joined" do
      post = %{id: "n1", title: "Late", body: "Open late.", published_on: ~D[2026-09-12]}
      news = s(:news, %{head: %{heading: "What's on"}}, key: "n", anchor: "whats-on")
      doc = render_page([hero(), points("a"), news], %{}, %{}, data: %{"n" => [post]})

      assert has?(doc, "#whats-on.bb-joined.bb-section-pad.pb-18")
    end
  end

  # Each component's section with enough content and data to draw
  # something, by key.
  defp drawn(:shared), do: {s(:shared, %{key: "lib"}), %{}}

  defp drawn(:columns) do
    children = [s(:details, det(), key: "one"), s(:details, det(), key: "two")]
    {s(:columns, %{variant: :even}, children: children), %{}}
  end

  defp drawn(type) do
    data = %{
      reviews: [review(1)],
      news: [%{id: "n1", title: "Late", body: "Open late.", published_on: ~D[2026-09-12]}]
    }

    section = s(type, Catalogue.placeholder(type))
    {section, Map.new(List.wrap(data[type] && {"#{type}", data[type]}))}
  end

  test "every component's section names its surface on its own element" do
    library = %{"lib" => points("lib")}

    for type <- Catalogue.keys(), type != :hero do
      {section, data} = drawn(type)
      doc = render_page([hero(), section], %{shared: library}, %{}, data: data)

      assert has?(doc, "main > [data-surface]"), "#{type} draws no section"
      refute has?(doc, "main > :not([data-surface])"), "#{type}"
    end
  end

  describe "surfaces in the editor" do
    test "the second of two plain sections is joined across the place to add between them" do
      doc = render_page([hero(), points("a"), points("b"), band("c"), points("d")], edit_ctx())

      assert has?(doc, "#edit-a + .bb-edit-gap + #edit-b > #b.bb-joined")
      refute has?(doc, "#a.bb-joined")
      refute has?(doc, "#c.bb-joined")
      refute has?(doc, "#d.bb-joined")
    end

    test "a fixed page's sections join with no places to add between them" do
      doc = render_page([hero(), points("a"), points("b")], edit_ctx(false))

      assert has?(doc, "#edit-a + #edit-b > #b.bb-joined")
    end

    test "a stand-in is drawn on its section's surface, and joins like it" do
      doc = render_page([hero(), points("a"), no_reviews("r"), points("c")], edit_ctx())

      assert has?(
               doc,
               "#edit-r > .bb-edit-stand-in.bb-surface-plain.bb-joined[data-surface='plain']"
             )

      assert text(doc, "#edit-r .bb-edit-stand-in") =~
               "Reviews · Nothing to show yet: there are no published reviews."

      assert has?(doc, "#c.bb-joined")
    end

    test "a misplaced hero keeps its neighbours apart, which meet on a visitor's page" do
      sections = [hero(), points("a"), s(:hero, %{heading: "y"}, key: "h2"), points("b")]

      refute has?(render_page(sections, edit_ctx()), "#b.bb-joined")
      assert has?(render_page(sections), "#b.bb-joined")
    end

    test "a shared section whose library section has gone is a stand-in on plain, and joins" do
      doc =
        render_page(
          [hero(), points("a"), s(:shared, %{key: "gone"}, key: "s1")],
          Map.put(edit_ctx(), :shared, %{})
        )

      assert has?(
               doc,
               "#edit-s1 > .bb-edit-stand-in.bb-surface-plain.bb-joined[data-surface='plain']"
             )

      assert text(doc, "#edit-s1 .bb-edit-stand-in") =~
               "Nothing to show yet: its section has left the shared library."
    end

    test "a shared section joins as its library section would" do
      library = %{"promise" => points("promise")}

      doc =
        render_page(
          [hero(), points("a"), s(:shared, %{key: "promise"}, key: "s1")],
          Map.put(edit_ctx(), :shared, library)
        )

      assert has?(doc, "#edit-s1 > #promise.bb-surface-plain.bb-joined")
    end
  end

  defp with_data(sections, data), do: render_page([hero() | sections], %{}, %{}, data: data)

  describe "reviews" do
    defp review(n),
      do: %{id: "r#{n}", quote: "Lovely #{n}.", name: "Client #{n}", reviewed_on: ~D[2026-05-01]}

    defp reviews(attrs \\ %{}),
      do: s(:reviews, Map.merge(%{note: "From *our visitors*."}, attrs), anchor: "reviews")

    test "show six at first, and the rest in place" do
      doc = with_data([reviews()], %{"reviews" => Enum.map(1..8, &review/1)})

      assert text(doc, "#reviews.page-section.bb-surface-plain.bb-wrap h2") =~ "What clients say"
      assert has?(doc, "#reviews-r1 blockquote")
      assert text(doc, "#reviews-r1 figcaption") =~ "May 2026"
      refute has?(doc, "#reviews-r6.hidden")
      assert has?(doc, "#reviews-r7.hidden[data-overflow]")
      assert text(doc, "#reviews-show-all") =~ "Show all 8"
      assert has?(doc, "#reviews p.bb-type-small em")
    end

    test "take the heading and the number shown from the section" do
      doc =
        with_data(
          [reviews(%{head: %{heading: "Kind words"}, initial: 2})],
          %{"reviews" => Enum.map(1..3, &review/1)}
        )

      assert text(doc, "#reviews h2") =~ "Kind words"
      assert has?(doc, "#reviews-r3.hidden")
      assert text(doc, "#reviews-show-all") =~ "Show all 3"
    end

    test "draw nothing when there are none" do
      refute has?(with_data([reviews()], %{"reviews" => []}), "#reviews")
    end
  end

  describe "what's on" do
    defp news,
      do:
        s(:news, %{head: %{heading: "What's on"}, empty: "No news yet."},
          key: "whats-on",
          anchor: "whats-on"
        )

    test "shows the latest posts" do
      post = %{id: "n1", title: "Late nights", body: "Open *late*.", published_on: ~D[2026-09-12]}
      doc = with_data([news()], %{"whats-on" => [post]})

      assert has?(doc, "#whats-on.page-section.bb-surface-plain.pb-18")
      assert text(doc, "#news-n1 h3") =~ "Late nights"
      assert text(doc, "#news-n1 p.bb-type-label") =~ "12 September 2026"
      assert has?(doc, "#news-n1 em")
      refute text(doc, "#whats-on") =~ "No news yet."
    end

    test "says so when there is no news" do
      doc = with_data([news()], %{"whats-on" => []})
      assert text(doc, "#whats-on p.bb-type-body") =~ "No news yet."
    end

    test "draws nothing at all with no news and no words for that" do
      bare = s(:news, %{head: %{heading: "What's on"}}, anchor: "whats-on")
      refute has?(with_data([bare], %{"whats-on" => []}), "#whats-on")
    end
  end
end
