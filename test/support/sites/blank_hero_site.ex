defmodule Billboard.Test.BlankHeroSite do
  @moduledoc """
  A site whose hero draws nothing (`Billboard.Test.Broken.BlankHero`), in
  the shop's layout, for `Billboard.ComponentCase`'s visitor check. It
  names no resources, so its sections are plain maps.
  """
  use Billboard.Site,
    otp_app: :billboard,
    components: [Billboard.Test.Broken.BlankHero],
    surfaces: [%{name: "plain", label: "Plain"}],
    offered: [page: ["plain"], stand_out: [], card: []],
    layout: Billboard.Test.Layout

  pages do
    page "/", "Home", kind: :free
  end
end
