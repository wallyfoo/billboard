defmodule Billboard.Test.Plain do
  @moduledoc "An embedded resource that isn't a component."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :body, :string, public?: true
  end
end
