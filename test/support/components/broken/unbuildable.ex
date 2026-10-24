defmodule Billboard.Test.Broken.Unbuildable do
  @moduledoc "A component whose placeholder fails its own validation, for `Billboard.ComponentCase`."
  use Billboard.Component

  component do
    key :unbuildable
    label "Unbuildable"
    hint "A placeholder that doesn't build."
    category :content
    renderer Billboard.Test.Broken.UnbuildableRenderer
    placeholder %{}
  end

  validations do
    validate present(:title), message: "add a title"
  end

  attributes do
    attribute :title, :string, public?: true
  end
end
