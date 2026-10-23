defmodule Billboard.Test.Band do
  @moduledoc "A stand-out section, at most two to a page, which the library may hold too."
  use Billboard.Component

  component do
    key :band
    label "Band"
    hint "One idea, set apart."
    category :band
    kinds [:free, :library]
    max 2
    surface_kind :stand_out
    placeholder %{heading: "Your band"}
  end

  attributes do
    attribute :heading, :string, public?: true
  end
end
