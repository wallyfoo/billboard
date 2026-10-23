defmodule Billboard.Test.NoDestroy do
  @moduledoc "A part without a destroy action, which `VerifyParts` refuses."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end
end
