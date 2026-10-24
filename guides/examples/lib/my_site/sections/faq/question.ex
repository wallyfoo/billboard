defmodule MySite.Sections.Faq.Question do
  @moduledoc "One question in a FAQ, with its answer."
  use Billboard.Part

  part do
    blank %{title: "Your question"}
  end

  editor do
    words :title, label: "Question", limit: 80
    words :body, as: :markdown, label: "Answer", limit: 400
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, public?: true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
