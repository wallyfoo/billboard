defmodule Billboard.Test.PartsByHand do
  @moduledoc "The parts of `Billboard.Test.Cards` and `Billboard.Test.Shelf`, written as plain attributes, to compare."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :head, Billboard.Test.Title, public?: true

    attribute :items, {:array, Billboard.Test.Item} do
      allow_nil? false
      default []
      public? true
      constraints min_length: 1, max_length: 4
    end

    attribute :label, Billboard.Test.Title,
      allow_nil?: false,
      public?: true,
      description: "The shelf's label."

    attribute :sign, Billboard.Test.Title,
      public?: true,
      default: %Billboard.Test.Title{title: "Open"}

    attribute :things, {:array, Billboard.Test.Item} do
      allow_nil? true
      default []
      public? true
      description "What's on it."
    end
  end
end
