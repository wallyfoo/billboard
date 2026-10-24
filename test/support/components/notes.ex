defmodule Billboard.Test.Notes do
  @moduledoc """
  A component whose list holds a site's own part (`Billboard.Part`), the
  guides' question, drawn by `Billboard.Test.NotesRenderer`. Its aside is
  Markdown offered under More, and its region picks from a set of choices
  the shop's context doesn't give, so the editor leaves its picker out.
  """
  use Billboard.Component

  alias MySite.Sections.Faq.Question

  component do
    key :notes
    label "Notes"
    hint "A list of questions."
    category :content
    renderer Billboard.Test.NotesRenderer
    placeholder %{items: [%{title: "First"}]}
    parts :items, Question, min: 1, max: 4
  end

  editor do
    field :items, as: :list, part: Question, min: 1, max: 4, item_label: "question"
    words :aside, as: :markdown, label: "Aside", limit: 200, more: true
    field :region, as: :choice, from: :region, label: "Region"
  end

  attributes do
    attribute :aside, :string, public?: true, constraints: [max_length: 400]
    attribute :region, :string, public?: true
  end
end
