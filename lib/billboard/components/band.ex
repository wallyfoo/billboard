defmodule Billboard.Components.Band do
  @moduledoc """
  One idea set apart, on a stand-out surface, between the page's other
  sections. `variant` `:heading` leads with a heading; `:quote_left` and
  `:quote_right` lead with a pull quote (`Billboard.Parts.Quote`) and set
  the other words beside it. A band takes an eyebrow, a body, and at
  most one `action` (`Billboard.Parts.Action`).

  Billboard adds `component`, the union's tag, always `:band`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  component do
    key :band
    label "Band"
    hint "One idea, set apart: a heading or a quote, and one action."
    category :band
    renderer Billboard.Sections.Band
    mirror? true
    surface_kind :stand_out
    placeholder %{heading: "Your band's heading"}

    part :quote, Billboard.Parts.Quote
    part :action, Billboard.Parts.Action
  end

  editor do
    field :variant, as: :variants, options: [:heading, :quote_left, :quote_right]
    words :eyebrow, label: "Eyebrow", limit: 30

    words :heading,
      label: "Heading",
      limit: 60,
      accent: true,
      hide_when: [variant: [:quote_left, :quote_right]]

    field :quote, as: :part, part: :quote, item_label: "quote", hide_when: [variant: [:heading]]
    words :body, as: :markdown, label: "Words", limit: 300
    field :action, as: :part, part: :action, optional: true, item_label: "action"
  end

  validations do
    validate present(:heading),
      where: [attribute_equals(:variant, :heading)],
      message: "add a heading"

    validate present(:quote),
      where: [attribute_in(:variant, [:quote_left, :quote_right])],
      message: "add a quote"
  end

  attributes do
    attribute :variant, :atom do
      allow_nil? false
      default :heading
      public? true
      constraints one_of: [:heading, :quote_left, :quote_right]
    end

    attribute :eyebrow, :string, public?: true, constraints: [max_length: 40]
    attribute :heading, :string, public?: true, constraints: [max_length: 120]
    attribute :body, :string, public?: true, constraints: [max_length: 600]
  end
end
