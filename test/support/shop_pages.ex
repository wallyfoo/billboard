defmodule Billboard.Test.ShopPages do
  @moduledoc """
  The shop's pages as the editor's tests need them, put live as a commit
  would (`Ash.Seed` and `Billboard.Cache.refresh/0`), so a test that
  calls one needs `preserve_cache` (`Billboard.Test.DataCase`). The
  shop's starters are thin; these are fuller. `offer/2` and
  `offer_cards/1` widen the shop's surfaces for a test, as a site with
  more than one of each would.
  """
  import Billboard.Test.Env, only: [put_shop!: 1]
  import Billboard.Test.Fixtures, only: [seed_section_fixture: 4]

  alias Billboard.Test.Shop

  @opts [authorize?: false]

  @doc "The home page: a hero with a photograph and no actions, text and image with an action, and words."
  def home! do
    make_live("/", [
      {"hero", :hero, %{heading: "Everything for the shop", photo: %{label: "The shop floor"}}},
      {"range", :text_media,
       %{variant: :text_only, head: %{heading: "Our range"}, actions: [%{kind: :call}]}},
      {"welcome", :text, %{body: "Come in."}, anchor: "welcome"}
    ])
  end

  @doc """
  The home page again, as a shop front: a hero with three actions, and
  text and image whose heading has one.
  """
  def storefront! do
    make_live("/", [
      {"hero", :hero,
       %{
         heading: "Everything for the shop",
         actions: [
           %{kind: :call},
           %{label: "Our story", path: "/about"},
           %{label: "Delivery", path: "/terms"}
         ]
       }},
      {"range", :text_media,
       %{
         variant: :text_only,
         head: %{heading: "Our range", action: %{label: "See all", path: "/about"}}
       }}
    ])
  end

  @doc """
  The about page: two Points, the first with a link on its first point,
  What's on, a quote band, Two columns, and the library's band shared.
  """
  def about! do
    make_live("/about", [
      {"hero", :hero, %{heading: "About us"}},
      {"also-here", :points,
       %{
         columns: 2,
         points: [
           %{
             title: "Step-free",
             body: "A ramp at the door.",
             link: %{label: "Getting here", path: "/terms"}
           },
           %{title: "Quiet hours", body: "Every morning."}
         ]
       }, anchor: "also-here"},
      {"story", :points, %{points: [%{title: "Founded"}, %{title: "Grown"}, %{title: "Here"}]},
       anchor: "story"},
      {"whats-on", :news, %{head: %{heading: "What's on"}}},
      {"late-opening", :band,
       %{variant: :quote_left, quote: %{body: "Open till eight."}, body: "On Thursdays."}},
      {"visit", :columns, %{},
       children: [
         {"where", :details, %{items: [%{label: "Where", body: "On the high street."}]}},
         {"when", :text, %{body: "Open every day."}}
       ]},
      {"promo-here", :shared, %{key: "promo"}}
    ])
  end

  @doc """
  An item page, whose hero takes its words from the product, and its
  details, one shown only in an aisle the shop no longer has.
  """
  def item! do
    make_live("/items/:slug", [
      {"hero", :hero, %{heading: "An item", bind: :product}},
      {"details", :details,
       %{
         items: [
           %{label: "Delivery", body: "Free over fifty."},
           %{label: "Sizing", body: "Runs small.", only_for_group: "socks"},
           %{label: "Returns", body: "Within thirty days."}
         ]
       }}
    ])
  end

  @doc "The terms page, whose hero is bound to a visit, which keeps its words."
  def visit! do
    make_live("/terms", [
      {"hero", :hero, %{heading: "Terms", bind: :visit}},
      {"terms", :text, %{body: "Be kind."}}
    ])
  end

  @doc """
  Puts `sections` live on the page at `pattern`, each `{key, type, attrs}`
  or `{key, type, attrs, opts}`, with `anchor:` and `children:` (more of
  the same) in `opts`.
  """
  def make_live(pattern, sections) do
    {:ok, page} = Shop.Pages.ensure_page(pattern, @opts)
    live = Ash.Seed.seed!(Shop.Version, %{page_id: page.id, status: :live})
    place(live, sections, nil)
    Billboard.Cache.refresh()
    :ok
  end

  defp place(live, sections, parent_id) do
    for {section, position} <- Enum.with_index(sections) do
      {key, type, attrs, opts} =
        case section do
          {key, type, attrs} -> {key, type, attrs, []}
          {key, type, attrs, opts} -> {key, type, attrs, opts}
        end

      seeded =
        seed_section_fixture(live, type, attrs, %{
          key: key,
          position: position,
          parent_id: parent_id,
          anchor: opts[:anchor]
        })

      place(live, Keyword.get(opts, :children, []), seeded.id)
    end
  end

  @doc """
  A shop of its own surfaces until the test ends, offering `page` to page
  sections and `stand_out` to bands. A site that names its surfaces
  names every offer it makes. Widening the offer changes application
  env, which every test that saves a section reads, so a test that calls
  it isn't async.
  """
  def offer(page, stand_out \\ ["loud"]) do
    put_shop!(
      surfaces: [
        %{name: "plain", label: "Plain"},
        %{name: "linen", label: "Linen"},
        %{name: "mist", label: "Mist"},
        %{name: "loud", label: "Loud"}
      ],
      offered: [page: page, stand_out: stand_out, card: []]
    )
  end

  @doc """
  A shop that offers Points the cards look, and `card` to its cards,
  until the test ends. Like `offer/2`, it isn't for an async test.
  """
  def offer_cards(card \\ ["plain", "loud"]) do
    put_shop!(options: [points: [look: [:rows, :cards]]])
    put_shop!(offered: [page: ["plain"], stand_out: ["loud"], card: card])
  end
end
