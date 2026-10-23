defmodule Billboard.Sections.Glyph do
  @moduledoc """
  The pieces each section's `glyph/1` draws from: bars for words, a block
  for a photograph, and a quote mark. A glyph is about 160×28 pixels,
  drawn in the editor's glyph colours, not the site's, since the section
  palette they appear in is the editor's chrome. All of it is spans, so
  it can sit inside a button. `bars/1`'s `on_dark` means drawn on a
  glyph's own dark block, such as the hero's, not on a surface.

  The editor's palette wraps each glyph in a span that names its
  component and variant.
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :on_dark, :boolean, default: false
  attr :rows, :integer, default: 2

  @doc "Lines of words: a full one, then shorter ones."
  def bars(assigns) do
    ~H"""
    <span class={["grid content-center gap-1", @class]}>
      <span class={["h-1 w-full", if(@on_dark, do: "bg-bb-glyph-paper", else: "bg-bb-glyph-ink")]}>
      </span>
      <span
        :for={row <- 2..@rows//1}
        class={[
          "h-1",
          if(rem(row, 2) == 0, do: "w-2/3", else: "w-5/6"),
          if(@on_dark, do: "bg-bb-glyph-paper/60", else: "bg-bb-glyph-soft")
        ]}
      >
      </span>
    </span>
    """
  end

  attr :class, :any, default: nil

  @doc "A photograph, or the placeholder that stands in for one."
  def photo(assigns) do
    ~H"""
    <span class={["bg-bb-glyph-faint", @class]}></span>
    """
  end

  attr :class, :any, default: "text-bb-glyph-accent"
  attr :side, :string, values: ~w(left right), default: "left"

  @doc "An opening (left) or closing (right) quote mark."
  def quote_mark(assigns) do
    ~H"""
    <span class={["font-bb-glyph text-[20px] leading-none", @class]}>
      {if @side == "left", do: "“", else: "”"}
    </span>
    """
  end
end
