defmodule Billboard.Test.Text do
  @moduledoc "Words, the one component that fits in a column."
  use Billboard.Component

  component do
    key :text
    label "Text"
    hint "A few words."
    category :paper
    column? true
    placeholder %{body: "Your words"}
  end

  validations do
    validate present(:body), message: "add some words"
  end

  attributes do
    attribute :body, :string, public?: true, constraints: [max_length: 600]
  end
end
