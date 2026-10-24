defmodule Billboard.Test.Notes do
  @moduledoc "A component whose list holds a site's own part (`Billboard.Part`)."
  use Billboard.Component

  alias MySite.Sections.Faq.Question

  component do
    key :notes
    label "Notes"
    hint "A list of questions."
    category :content
    placeholder %{items: [%{title: "First"}]}
    parts :items, Question, min: 1, max: 4
  end

  editor do
    field :items, as: :list, part: Question, min: 1, max: 4, item_label: "question"
  end
end
