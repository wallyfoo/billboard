defmodule Billboard.Test.Section do
  @moduledoc """
  Holds one component in a tagged union, as a site's section does, so
  tests can see how a component's errors come through it.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    attribute :content, :union do
      allow_nil? false
      public? true

      constraints types: [
                    cards: [type: Billboard.Test.Cards, tag: :component, tag_value: :cards],
                    banner: [type: Billboard.Test.Banner, tag: :component, tag_value: :banner]
                  ]
    end
  end
end
