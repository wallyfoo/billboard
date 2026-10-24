defmodule Billboard.Test.Cards do
  @moduledoc """
  A component with a part and a list of parts, and settings a site can
  narrow: a `look` with `one_of`, bounded `columns`, and its layouts,
  which its `editor` section offers, with its list of items. Its items
  are points but for their words and links, which an item doesn't hold.
  """
  use Billboard.Component

  component do
    key :cards
    label "Cards"
    hint "A few cards side by side."
    category :paper
    renderer Billboard.Test.CardsRenderer
    placeholder %{head: %{title: "Your cards"}, items: [%{title: "Your card"}]}

    part :head, Billboard.Test.Title
    parts :items, Billboard.Test.Item, min: 1, max: 4
  end

  editor do
    field :variant, as: :variants, options: [:text_only, :media_left, :media_right]
    field :look, as: :select, label: "Look", options: [{"Rows", :rows}, {"Cards", :cards}]

    field :columns,
      as: :select,
      label: "Columns",
      options: [{"Two", 2}, {"Three", 3}, {"Four", 4}]

    field :items,
      as: :list,
      part: :point,
      except: [:body, :link],
      min: 1,
      max: 4,
      item_label: "card"
  end

  attributes do
    attribute :columns, :integer do
      allow_nil? false
      default 3
      public? true
      constraints min: 2, max: 4
    end

    attribute :variant, :atom do
      allow_nil? false
      default :text_only
      public? true
      constraints one_of: [:text_only, :media_left, :media_right]
    end

    attribute :look, :atom do
      allow_nil? false
      default :rows
      public? true
      constraints one_of: [:rows, :cards]
    end
  end
end
