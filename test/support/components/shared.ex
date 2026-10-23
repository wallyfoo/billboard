defmodule Billboard.Test.Shared do
  @moduledoc """
  A section from the library. `:shared` is a key billboard reserves: it
  draws the library section its `key` names.
  """
  use Billboard.Component

  component do
    key :shared
    label "Shared section"
    hint "A section from the shared library."
    category :special
    kinds [:free, :item]
    surface_from :library
  end

  attributes do
    attribute :key, :string, allow_nil?: false, public?: true
  end
end
