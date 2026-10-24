defmodule Billboard.Test.OwnHero do
  @moduledoc """
  A site's own hero, in the stock hero's place (key `:hero`), drawn by
  `Billboard.Test.OwnHeroRenderer` with markup of its own.
  """
  use Billboard.Component

  component do
    key :hero
    label "Hero"
    hint "The page's heading, drawn the site's own way."
    category :opener
    renderer Billboard.Test.OwnHeroRenderer
    max 1
    surface_from :layout
    placeholder %{heading: "Your heading"}
  end

  editor do
    words :heading, label: "Heading", limit: 60
  end

  attributes do
    attribute :heading, :string, public?: true
  end
end
