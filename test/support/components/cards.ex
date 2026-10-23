defmodule Billboard.Test.Cards do
  @moduledoc "A component with a part and a list of parts, as Points has."
  use Billboard.Component

  component do
    key :cards
    label "Cards"
    hint "A few cards side by side."
    category :paper
    placeholder %{head: %{title: "Your cards"}}

    part :head, Billboard.Test.Title
    parts :items, Billboard.Test.Item, min: 1, max: 4
  end

  attributes do
    attribute :columns, :integer, public?: true, default: 3
  end
end
