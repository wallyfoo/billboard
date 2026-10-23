defmodule Billboard.Test.Faq do
  @moduledoc "A component with every kind of editor entry, as a site's FAQ might have."
  use Billboard.Component

  @title_limit 60

  component do
    key :faq
    label "Questions"
    hint "Questions and their answers."
    category :content
    renderer Billboard.Test.FaqRenderer
    filler? false
    context [:scope]
    rules [Billboard.Test.NoQuestions]
    placeholder %{title: "Questions"}

    parts :questions, Billboard.Test.Question, min: 1, max: 8
  end

  editor do
    field :style, as: :select, label: "Style", options: [{"Open", :open}, {"Folded", :folded}]
    words :title, label: "Title", limit: @title_limit, accent: true
    field :note, as: :note, text: "Answers fold on phones."
    words :intro, as: :markdown, label: "Introduction", limit: 200, more: true

    field :questions,
      as: :list,
      part: :detail,
      except: [:only_for_group],
      max: 8,
      item_label: "question"

    words :sign_off, label: "Sign-off", more: true
  end

  attributes do
    attribute :title, :string, public?: true
    attribute :intro, :string, public?: true
    attribute :sign_off, :string, public?: true

    attribute :style, :atom do
      allow_nil? false
      default :open
      public? true
      constraints one_of: [:open, :folded]
    end
  end
end
