defmodule MySite.Sections.Faq do
  @moduledoc """
  Questions and their answers, under a title. The answers are open, or
  folded under their questions for a long list. A question with no
  answer yet is a warning in the editor.
  """
  use Billboard.Component

  # guide:component
  component do
    key :faq
    label "Questions"
    hint "Questions and their answers."
    category :content
    renderer MySiteWeb.Sections.Faq
    rules [MySite.Sections.Faq.UnansweredQuestions]
    placeholder %{title: "Your questions", questions: [%{title: "Your first question"}]}

    parts :questions, MySite.Sections.Faq.Question, min: 1, max: 12
  end

  # guide:end

  # guide:editor
  editor do
    field :style, as: :select, label: "Answers", options: [{"Open", :open}, {"Folded", :folded}]
    words :title, label: "Title", limit: 60, accent: true

    field :questions,
      as: :list,
      part: MySite.Sections.Faq.Question,
      min: 1,
      max: 12,
      item_label: "question"
  end

  # guide:end

  # guide:attributes
  attributes do
    attribute :title, :string, public?: true

    attribute :style, :atom do
      allow_nil? false
      default :open
      public? true
      constraints one_of: [:open, :folded]
    end
  end

  # guide:end
end
