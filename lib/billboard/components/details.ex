defmodule Billboard.Components.Details do
  @moduledoc """
  Labelled facts (`Billboard.Parts.Detail`), such as who you'll see or
  how cancelling works, under an optional `head` (`Billboard.Parts.Head`).
  `width` is `:standard` or `:narrow`. A detail limited to one scope
  shows only on pages with that scope (`ctx.context.scope`,
  `Billboard.Context`).

  Billboard adds `component`, the union's tag, always `:details`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  component do
    key :details
    label "Details"
    hint "Labelled facts, such as who you'll see or how cancelling works."
    category :content
    renderer Billboard.Sections.Details
    context [:scope]
    column? true
    placeholder %{items: [%{label: "Your label", body: "What a visitor should know."}]}

    part :head, Billboard.Parts.Head
    parts :items, Billboard.Parts.Detail, min: 1, max: 12
  end

  editor do
    field :width,
      as: :select,
      label: "Width",
      options: [{"Standard", :standard}, {"Narrow", :narrow}]

    field :head, as: :part, part: :head, optional: true, item_label: "heading"
    field :items, as: :list, part: :detail, min: 1, max: 12, item_label: "detail"
  end

  attributes do
    attribute :width, :atom do
      allow_nil? false
      default :standard
      public? true
      constraints one_of: [:standard, :narrow]
    end
  end
end
