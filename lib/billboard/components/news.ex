defmodule Billboard.Components.News do
  @moduledoc """
  The latest `limit` news posts, under a `head` (`Billboard.Parts.Head`).
  `empty` is shown when there are none. The posts are the site's, given
  by section key in the page's data (`Billboard.Sections.News` lists
  what each holds). Its placeholder, "What's on", reads as finished
  words, so it isn't filler.

  Billboard adds `component`, the union's tag, always `:news`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  component do
    key :news
    label "What's on"
    hint "The latest news posts."
    category :data
    renderer Billboard.Sections.News
    filler? false
    max 1
    placeholder %{head: %{heading: "What's on"}}

    part :head, Billboard.Parts.Head, allow_nil?: false
  end

  editor do
    field :head, as: :part, part: :head, item_label: "heading"
    field :limit, as: :number, label: "Posts shown", min: 1, max: 6
    words :empty, label: "When there's no news", limit: 120, more: true
  end

  attributes do
    attribute :empty, :string, public?: true, constraints: [max_length: 200]

    attribute :limit, :integer do
      allow_nil? false
      default 2
      public? true
      constraints min: 1, max: 6
    end
  end
end
