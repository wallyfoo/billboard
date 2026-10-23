defmodule Billboard.Test.Cards do
  @moduledoc """
  A component with a part and a list of parts, and settings a site can
  narrow: a `look` with `one_of`, and bounded `columns`.
  """
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
    attribute :columns, :integer do
      allow_nil? false
      default 3
      public? true
      constraints min: 2, max: 4
    end

    attribute :look, :atom do
      allow_nil? false
      default :rows
      public? true
      constraints one_of: [:rows, :cards]
    end
  end
end
