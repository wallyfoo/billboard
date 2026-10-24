defmodule Billboard.Components.Hero do
  @moduledoc """
  The page's opening block, drawn as one with the page's header. It
  holds the H1, so every page but the shared-sections library has exactly
  one, first.

  `variant` sets where the photograph sits: `:media_right` (the
  default), `:media_left`, or `:text_only`. `size` `:auto` sets the
  heading at display size until it passes 42 characters. `bind` takes
  the heading, eyebrow, and lede from what the page is about instead
  (`Billboard.Context`), or `:none`. It takes up to three `actions` and
  one `photo` (`Billboard.Parts.Action` and `Billboard.Parts.Photo`).

  A binding is checked against the site's when it changes, so a hero
  saved with one the site has stopped offering keeps it, and draws its
  own words. A stored binding is an atom only the site's context module
  names; it loads because `Billboard.Cache` loads that module before it
  warms.

  Billboard adds `component`, the union's tag, always `:hero`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  @heading_limit 42
  @lede_limit 180

  @doc "The heading's length past which an `:auto` hero sets it at h1 size."
  def heading_limit, do: @heading_limit

  @doc "The lede's length past which an `:auto` hero shortens it for a visitor."
  def lede_limit, do: @lede_limit

  component do
    key :hero
    label "Hero"
    hint "The page's heading, with a photograph either side or none."
    category :opener
    renderer Billboard.Sections.Hero
    context [:bindings]
    max 1
    mirror? true
    surface_from :layout
    # It starts text only, since it has no photograph yet: a layout with
    # one arrives with the photograph's placeholder, ready for one.
    placeholder %{variant: :text_only, heading: "Your heading"}

    parts :actions, Billboard.Parts.Action, max: 3, allow_nil?: true
    part :photo, Billboard.Parts.Photo
  end

  editor do
    field :variant, as: :variants, options: [:text_only, :media_left, :media_right]

    field :size,
      as: :select,
      label: "Heading size",
      options: [{"Auto", :auto}, {"Large", :display}, {"Standard", :h1}]

    field :bound, as: :binding_note
    words :eyebrow, label: "Eyebrow", limit: 30, bound: :hide
    words :heading, label: "Heading", limit: @heading_limit, accent: true, bound: :hide
    words :lede, as: :markdown, label: "Opening lines", limit: @lede_limit, bound: :hide
    field :actions, as: :list, part: :action, max: 3, item_label: "action"
    field :photo, as: :photo, ratio: "aspect-[4/3]", hide_when: [variant: [:text_only]]
  end

  validations do
    validate present(:heading),
      where: [attribute_equals(:bind, :none)],
      message: "add a heading"

    validate Billboard.Components.Hero.Validations.BindOffered
  end

  attributes do
    attribute :variant, :atom do
      allow_nil? false
      default :media_right
      public? true
      constraints one_of: [:media_left, :media_right, :text_only]
    end

    attribute :size, :atom do
      allow_nil? false
      default :h1
      public? true
      constraints one_of: [:auto, :display, :h1]
    end

    # A binding names what the hero takes its words from on its page
    # (`Billboard.Context`), or `:none`. The site's bindings aren't known
    # when billboard compiles, so it has no `one_of`.
    attribute :bind, :atom do
      allow_nil? false
      default :none
      public? true
    end

    attribute :eyebrow, :string, public?: true, constraints: [max_length: 40]
    attribute :heading, :string, public?: true, constraints: [max_length: 120]
    attribute :lede, :string, public?: true, constraints: [max_length: 600]
  end
end
