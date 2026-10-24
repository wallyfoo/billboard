defmodule Billboard.Test.Broken.BlankHero do
  @moduledoc """
  A site's own hero whose renderer draws nothing in the page's hero
  block, for `Billboard.ComponentCase`, on `Billboard.Test.BlankHeroSite`.
  """
  use Billboard.Component

  component do
    key :hero
    label "Hero"
    hint "A hero that draws nothing."
    category :opener
    renderer Billboard.Test.Broken.BlankHeroRenderer
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
