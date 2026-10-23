defmodule Billboard.Test.PlainSite do
  @moduledoc """
  A `use Billboard.Site` site with every answer a component-only site
  gives, and its pages, for the tests of `use Billboard.Site` and of
  `Billboard.Directory`. It names no resources, repo, PubSub, or starter.
  """
  use Billboard.Site,
    otp_app: :billboard,
    components: [Billboard.Test.Banner, Billboard.Test.Cards, Billboard.Test.Note],
    surfaces: [%{name: "plain", label: "Plain"}, %{name: "loud", label: "Loud"}],
    offered: [page: ["plain"], stand_out: ["loud"], card: []],
    options: [cards: [look: [:rows], items: 1..3]],
    reserved_ids: [ids: ~w(shop-header), prefixes: ~w(item-)]

  pages do
    page "/", "Home", kind: :free, title: "Everything for the shop"
    page "/terms", "Terms", kind: :fixed, fixed: [:note]
  end
end
