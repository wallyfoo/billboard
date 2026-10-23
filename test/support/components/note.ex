defmodule Billboard.Test.Note do
  @moduledoc "A component that sets only the required options, so the rest take their defaults."
  use Billboard.Component

  component do
    key :note
    label "Note"
    hint "A few words."
    category :paper
  end

  attributes do
    attribute :body, :string, public?: true
    attribute :internal, :string
  end
end
