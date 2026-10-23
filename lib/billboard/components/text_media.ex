defmodule Billboard.Components.TextMedia do
  @moduledoc """
  A heading, some words, and a photograph. `variant` sets where the
  photograph sits: `:media_left`, `:media_right` (the default), or
  `:text_only`, which has none. It takes a `head` (`Billboard.Parts.Head`),
  a `body`, up to two `actions` (`Billboard.Parts.Action`), and a `photo`
  (`Billboard.Parts.Photo`).

  Billboard adds `component`, the union's tag, always `:text_media`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  component do
    key :text_media
    label "Text and image"
    hint "A heading, some words, and a photograph either side."
    category :content
    renderer Billboard.Sections.TextMedia
    mirror? true
    # It starts text only, since it has no photograph yet.
    placeholder %{variant: :text_only, head: %{heading: "Your heading"}}

    part :head, Billboard.Parts.Head, allow_nil?: false
    parts :actions, Billboard.Parts.Action, max: 2, allow_nil?: true
    part :photo, Billboard.Parts.Photo
  end

  editor do
    field :variant, as: :variants, options: [:text_only, :media_left, :media_right]
    field :head, as: :part, part: :head, item_label: "heading"
    words :body, as: :markdown, label: "Words", limit: 600
    field :actions, as: :list, part: :action, max: 2, item_label: "action"
    field :photo, as: :photo, ratio: "aspect-[4/3]", hide_when: [variant: [:text_only]]
  end

  validations do
    validate present(:photo),
      where: [attribute_does_not_equal(:variant, :text_only)],
      message: "add a photograph, or make this text only"
  end

  attributes do
    attribute :variant, :atom do
      allow_nil? false
      default :media_right
      public? true
      constraints one_of: [:media_left, :media_right, :text_only]
    end

    attribute :body, :string, public?: true, constraints: [max_length: 1200]
  end
end
