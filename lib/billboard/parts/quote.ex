defmodule Billboard.Parts.Quote do
  @moduledoc """
  A pull quote: what was said, and optionally who said it and a line about
  them, such as when or for what.

  Billboard adds nothing to a part; a part in a list has an id, as
  `Billboard.Component` explains.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    attribute :body, :string do
      allow_nil? false
      public? true
      constraints max_length: 400
    end

    attribute :name, :string, public?: true, constraints: [max_length: 40]
    attribute :meta, :string, public?: true, constraints: [max_length: 40]
  end
end
