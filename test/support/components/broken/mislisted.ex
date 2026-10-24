defmodule Billboard.Test.Broken.Mislisted do
  @moduledoc """
  A component whose list holds questions but names the detail as its
  part, so an item added to it starts as a detail's blank, which a
  question refuses. For `Billboard.ComponentCase`.
  """
  use Billboard.Component

  component do
    key :mislisted
    label "Mislisted"
    hint "A list that names the wrong part."
    category :content
    renderer Billboard.Test.Broken.MislistedRenderer
    placeholder %{items: [%{question: "Open late?"}]}
    parts :items, Billboard.Test.Question, min: 1, max: 4
  end

  editor do
    field :items, as: :list, part: :detail, max: 4, item_label: "question"
  end
end
