defmodule Billboard.Test.Hero do
  @moduledoc """
  The test site's opener. `:hero` is a key billboard reserves: a page
  opens with exactly one, it stays first, and it can't be removed. It
  takes the layout's surface, and holds up to three actions.
  """
  use Billboard.Component

  component do
    key :hero
    label "Hero"
    hint "The page's heading."
    category :opener
    kinds [:free, :item, :fixed]
    max 1
    mirror? true
    surface_from :layout
    placeholder %{heading: "Your heading"}

    parts :actions, Billboard.Test.Action, max: 3, allow_nil?: true
  end

  validations do
    validate present(:heading), message: "add a heading"
  end

  attributes do
    attribute :heading, :string, public?: true, constraints: [max_length: 120]
  end
end
