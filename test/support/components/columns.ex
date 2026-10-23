defmodule Billboard.Test.Columns do
  @moduledoc "Two columns. `:columns` is a key billboard reserves: its section holds two others as children."
  use Billboard.Component

  component do
    key :columns
    label "Two columns"
    hint "Two sections side by side."
    category :layout
    kinds [:free]
    mirror? true
  end

  attributes do
    attribute :variant, :atom,
      allow_nil?: false,
      default: :even,
      public?: true,
      constraints: [one_of: [:even, :wide_left, :wide_right]]
  end
end
