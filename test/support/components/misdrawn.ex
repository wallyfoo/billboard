defmodule Billboard.Test.Misdrawn do
  @moduledoc """
  A component drawn as a renderer should draw one, but for the mistakes
  a test asks `Billboard.Test.MisdrawnRenderer` to make, each one
  `Billboard.ComponentCase` should name. It has words, an optional head,
  points with links, buttons, and a photograph, so it has every control
  the open section's renderer draws. It's on the shop, kept off every
  page's palette by the shop's `kinds:`.
  """
  use Billboard.Component

  component do
    key :misdrawn
    label "Misdrawn"
    hint "Drawn wrong, one way at a time."
    category :content
    renderer Billboard.Test.MisdrawnRenderer

    placeholder %{
      title: "Plain words",
      head: %{heading: "A heading"},
      points: [%{title: "A point"}]
    }

    part :head, Billboard.Parts.Head
    parts :points, Billboard.Parts.Point, min: 1, max: 4
    parts :actions, Billboard.Parts.Action, max: 2, allow_nil?: true
    part :photo, Billboard.Parts.Photo
  end

  editor do
    words :title, label: "Title", limit: 60
    field :head, as: :part, part: :head, optional: true, item_label: "heading"
    field :points, as: :list, part: :point, min: 1, max: 4, item_label: "point"
    field :actions, as: :list, part: :action, max: 2, item_label: "action"
    field :photo, as: :photo, ratio: "aspect-[4/3]"
  end

  attributes do
    attribute :title, :string, public?: true
  end
end
