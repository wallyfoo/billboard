defmodule Billboard.Components.Columns do
  @moduledoc """
  Two sections side by side. The sections themselves are the columns
  section's children; this holds only how the width is shared: `:even`,
  `:wide_left`, or `:wide_right`. It's drawn by
  `Billboard.Sections.Columns`.

  Billboard adds `component`, the union's tag, always `:columns`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  component do
    key :columns
    label "Two columns"
    hint "Two sections side by side."
    category :layout
    renderer Billboard.Sections.Columns
    mirror? true
    # Two columns needs two sections inside it as well; the editor adds
    # two, each with its own placeholder.
  end

  editor do
    field :variant, as: :variants, options: [:even, :wide_left, :wide_right]
  end

  attributes do
    attribute :variant, :atom do
      allow_nil? false
      default :even
      public? true
      constraints one_of: [:even, :wide_left, :wide_right]
    end
  end
end
