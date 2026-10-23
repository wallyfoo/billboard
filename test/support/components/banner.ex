defmodule Billboard.Test.Banner do
  @moduledoc "A component that sets every option of the `component` section."
  use Billboard.Component

  component do
    key :banner
    label "Banner"
    hint "One idea, set apart."
    category :band
    kinds [:free]
    max 2
    mirror? true
    surface_kind :stand_out
    surface_from :library
    placeholder %{heading: "Your banner"}
  end

  attributes do
    attribute :heading, :string, public?: true
  end
end
