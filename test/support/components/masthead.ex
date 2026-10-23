defmodule Billboard.Test.Masthead do
  @moduledoc "A component the layout draws, so it takes the layout's surface, as a hero does."
  use Billboard.Component

  component do
    key :masthead
    label "Masthead"
    hint "The page's title, on the layout's ground."
    category :hero
    surface_from :layout
  end

  attributes do
    attribute :title, :string, public?: true
  end
end
