defmodule Billboard.Test.Stamp do
  @moduledoc """
  A component that writes its own `create` action, which billboard keeps,
  and its own `component` attribute, written as billboard would add it.
  """
  use Billboard.Component

  component do
    key :stamp
    label "Stamp"
    hint "A mark that can't be changed after it's made."
    category :paper
  end

  actions do
    create :create do
      primary? true
      accept [:word]
    end
  end

  attributes do
    attribute :component, :atom do
      allow_nil? false
      default :stamp
      public? true
      constraints one_of: [:stamp]
    end

    attribute :word, :string, public?: true
    attribute :size, :integer, public?: true
  end
end
