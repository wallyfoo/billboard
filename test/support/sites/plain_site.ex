defmodule Billboard.Test.PlainSite do
  @moduledoc """
  A `use Billboard.Site` site with every answer a component-only site
  gives, and its pages, for the tests of `use Billboard.Site` and of
  `Billboard.Directory`: its actions and context, the palette narrowed,
  and an example path among them. It names no resources, repo, PubSub,
  or starter.
  """
  use Billboard.Site,
    otp_app: :billboard,
    components: [Billboard.Test.Banner, Billboard.Test.Cards, Billboard.Test.Note],
    surfaces: [%{name: "plain", label: "Plain"}, %{name: "loud", label: "Loud"}],
    offered: [page: ["plain"], stand_out: ["loud"], card: []],
    options: [cards: [look: [:rows], items: 1..3]],
    reserved_ids: [ids: ~w(shop-header), prefixes: ~w(item-)],
    actions: Billboard.Test.Actions,
    context: Billboard.Test.Context,
    kinds: [cards: [:free]],
    palette: [hints: [note: "A short note."], categories: [paper: "In the shop"]],
    example_path: "/terms"

  pages do
    page "/", "Home", kind: :free, title: "Everything for the shop"
    page "/terms", "Terms", kind: :fixed, fixed: [:note]
  end
end
