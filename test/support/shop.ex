defmodule Billboard.Test.Shop do
  @moduledoc """
  The site the engine's tests run against, and the configured site: its
  answers, its `pages` section, and its resources on the test database.
  A test overrides its surfaces, offers, options, rules, kinds, and
  palette with `Billboard.Test.Env.put_shop!/1`.

  It's on billboard's stock components, with two of its own, Cards and
  Text. Its `kinds:` keep the hero off the library, the band and the
  points to free pages and the library, Two columns to free pages, and
  Shared to free and item pages. Its action kinds and context are the
  test site's (`Billboard.Test.Actions` and `Billboard.Test.Context`),
  its reviews and news are a test's own (`Billboard.Test.Data`), and its
  chrome is `Billboard.Test.Layout`. Its pages: a free home page and
  about page, an item page whose kind takes no Two columns, a fixed
  terms page, and the library.
  """
  alias Billboard.Test

  use Billboard.Site,
    otp_app: :billboard,
    repo: Test.Repo,
    pubsub: Test.PubSub,
    domain: Test.Shop.Pages,
    resources: [
      page: Test.Shop.Page,
      version: Test.Shop.Version,
      section: Test.Shop.Section,
      content: Test.Shop.Content
    ],
    components: [
      Billboard.Components.Hero,
      Billboard.Components.Band,
      Test.Cards,
      Test.Text,
      Billboard.Components.Points,
      Billboard.Components.TextMedia,
      Billboard.Components.Details,
      Billboard.Components.Reviews,
      Billboard.Components.News,
      Billboard.Components.Columns,
      Billboard.Components.Shared
    ],
    surfaces: [%{name: "plain", label: "Plain"}, %{name: "loud", label: "Loud"}],
    offered: [page: ["plain"], stand_out: ["loud"], card: []],
    starter: Test.Shop.Starter,
    actions: Test.Actions,
    context: Test.Context,
    data: Test.Data,
    layout: Test.Layout,
    kinds: [
      hero: [:free, :item, :fixed],
      band: [:free, :library],
      points: [:free, :library],
      columns: [:free],
      shared: [:free, :item]
    ],
    reserved_ids: [
      ids: ~w(shop-header),
      prefixes: ~w(item-),
      suffixes: ~w(-more),
      owned: %{"basket" => :cards}
    ]

  pages do
    page "/", "Home", kind: :free, title: "Everything for the shop"
    page "/about", "About", kind: :free
    page "/items/:slug", "An item", kind: :item
    page "/terms", "Terms", kind: :fixed, fixed: [:hero, :text]
  end
end
