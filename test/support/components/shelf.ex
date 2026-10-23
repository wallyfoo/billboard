defmodule Billboard.Test.Shelf do
  @moduledoc "A component whose parts set the other options, and leave `min` and `max` out."
  use Billboard.Component

  component do
    key :shelf
    label "Shelf"
    hint "Things in a row."
    category :paper

    part :label, Billboard.Test.Title, allow_nil?: false, description: "The shelf's label."

    parts :things, Billboard.Test.Item do
      allow_nil? true
      description "What's on it."
    end
  end
end
