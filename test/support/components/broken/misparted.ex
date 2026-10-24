defmodule Billboard.Test.Broken.Misparted do
  @moduledoc """
  A component whose optional part holds a question but names the detail
  as its part, so a part added to it starts as a detail's blank, which a
  question refuses. For `Billboard.ComponentCase`.
  """
  use Billboard.Component

  component do
    key :misparted
    label "Misparted"
    hint "A part that names the wrong part."
    category :content
    renderer Billboard.Test.Broken.BareRenderer
    placeholder %{items: [%{question: "Open late?"}]}
    parts :items, Billboard.Test.Question, min: 1, max: 4
    part :lead, Billboard.Test.Question
  end

  editor do
    field :lead, as: :part, part: :detail, optional: true, item_label: "question"
  end
end
