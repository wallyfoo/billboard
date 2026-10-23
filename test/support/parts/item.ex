defmodule Billboard.Test.Item do
  @moduledoc "A part that sits in a list, so it has an id."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
  end
end
