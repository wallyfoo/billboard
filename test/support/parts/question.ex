defmodule Billboard.Test.Question do
  @moduledoc "A part that sits in a list, so it has an id: a question and its answer."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :question, :string, allow_nil?: false, public?: true
    attribute :answer, :string, public?: true
  end
end
