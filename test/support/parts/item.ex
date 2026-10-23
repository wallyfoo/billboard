defmodule Billboard.Test.Item do
  @moduledoc """
  A part that sits in a list, so it has an id. Its card may be drawn on a
  surface of its own, from the site's `:card` offer.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  validations do
    validate {Billboard.Validations.SurfaceOffered, kind: :card}
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :surface, :string, public?: true
  end
end
