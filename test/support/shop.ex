defmodule Billboard.Test.Shop do
  @moduledoc """
  The site the engine's tests run against, and the configured site: its
  answers and its `pages` section. A test overrides its surfaces, offers,
  options, and rules with `Billboard.Test.Env.put_shop!/1`.

  Its pages: a free home page and about page, an item page whose kind
  takes no Two columns, a fixed terms page, and the library.
  """
  alias Billboard.Test

  use Billboard.Site,
    otp_app: :billboard,
    pubsub: Test.PubSub,
    components: [Test.Hero, Test.Band, Test.Cards, Test.Text, Test.Columns, Test.Shared],
    surfaces: [%{name: "plain", label: "Plain"}, %{name: "loud", label: "Loud"}],
    offered: [page: ["plain"], stand_out: ["loud"], card: []],
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
