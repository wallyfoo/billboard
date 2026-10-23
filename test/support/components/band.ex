defmodule Billboard.Test.Band do
  @moduledoc """
  A stand-out section, at most two to a page, which the library may hold
  too. Its one action is a single part with an id.
  """
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

    part :action, Billboard.Test.Action
  end

  attributes do
    attribute :heading, :string, public?: true
  end
end
