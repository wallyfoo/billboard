defmodule Billboard.Test.NoId do
  @moduledoc "A part without an id, which `VerifyParts` refuses in a list."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    attribute :title, :string, public?: true
  end
end
