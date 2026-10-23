defmodule Billboard.Test.Title do
  @moduledoc "A part used singly, so it needs no id."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    attribute :title, :string, public?: true
  end
end
