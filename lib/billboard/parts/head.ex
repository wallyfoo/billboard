defmodule Billboard.Parts.Head do
  @moduledoc """
  A section's head: an optional eyebrow, a heading, and at most one action.

  Billboard adds nothing to a part; a part in a list has an id, as
  `Billboard.Component` explains.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    attribute :eyebrow, :string, public?: true, constraints: [max_length: 40]

    attribute :heading, :string do
      allow_nil? false
      public? true
      constraints max_length: 120
    end

    attribute :action, Billboard.Parts.Action, public?: true
  end
end
