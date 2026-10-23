defmodule Billboard.Test.Action do
  @moduledoc "A part in a list, so it has an id, with a style the rules count primaries by."
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :label, :string, allow_nil?: false, public?: true

    attribute :style, :atom do
      allow_nil? false
      default :secondary
      public? true
      constraints one_of: [:primary, :secondary]
    end
  end
end
