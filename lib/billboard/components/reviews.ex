defmodule Billboard.Components.Reviews do
  @moduledoc """
  Published reviews: one on its own, or a grid when there are more. Shows
  `initial` reviews at first, under a `head` (`Billboard.Parts.Head`,
  "What clients say" unless changed), with an optional `note` beneath.
  The reviews are the site's, given by section key in the page's data
  (`Billboard.Sections.Reviews` lists what each holds).

  Billboard adds `component`, the union's tag, always `:reviews`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  alias Billboard.Parts

  component do
    key :reviews
    label "Reviews"
    hint "Published reviews."
    category :data
    renderer Billboard.Sections.Reviews
    max 1

    part :head, Parts.Head, allow_nil?: false, default: %Parts.Head{heading: "What clients say"}
  end

  editor do
    field :head, as: :part, part: :head, item_label: "heading"
    words :note, as: :markdown, label: "Note", limit: 200
    field :initial, as: :number, label: "Reviews shown at first", min: 1, max: 24
  end

  attributes do
    attribute :note, :string, public?: true, constraints: [max_length: 300]

    attribute :initial, :integer do
      allow_nil? false
      default 6
      public? true
      constraints min: 1, max: 24
    end
  end
end
