defmodule Billboard.Components.Points do
  @moduledoc """
  One to four short points side by side (`Billboard.Parts.Point`), in
  two, three, or four `columns`, under an optional `head`
  (`Billboard.Parts.Head`).

  Its `look` is `:rows`, each point under a hairline, or `:cards`, each a
  bounded card that may sit on a surface of its own (`Point.surface`).
  The site says which looks, columns, and numbers of points it offers in
  its options (`Billboard.SiteOptions`), which billboard keeps it to, and
  which a new section starts with.

  Billboard adds `component`, the union's tag, always `:points`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  component do
    key :points
    label "Points"
    hint "Short points side by side."
    category :content
    renderer Billboard.Sections.Points
    placeholder %{points: [%{title: "Your first point"}]}

    part :head, Billboard.Parts.Head
    parts :points, Billboard.Parts.Point, min: 1, max: 4
  end

  editor do
    field :look, as: :select, label: "Look", options: [{"Rows", :rows}, {"Cards", :cards}]

    field :columns,
      as: :select,
      label: "Columns",
      options: [{"Two", 2}, {"Three", 3}, {"Four", 4}]

    field :head, as: :part, part: :head, optional: true, item_label: "heading"
    field :points, as: :list, part: :point, min: 1, max: 4, item_label: "point"
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
