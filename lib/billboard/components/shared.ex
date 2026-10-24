defmodule Billboard.Components.Shared do
  @moduledoc """
  A section from the shared library, shown here. `key` is the key of the
  library section it shows. It's drawn by `Billboard.Sections.Shared`,
  on its library section's surface (`surface_from :library`).

  Billboard adds `component`, the union's tag, always `:shared`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  component do
    key :shared
    label "Shared section"
    hint "A section from the shared library."
    category :special
    renderer Billboard.Sections.Shared
    surface_from :library
    # A shared section also needs the key of a library section, which only
    # the editor knows, so the editor supplies that rather than a placeholder.
  end

  editor do
    field :key, as: :shared, label: "Library section"
  end

  attributes do
    attribute :key, :string do
      allow_nil? false
      public? true
    end
  end
end
