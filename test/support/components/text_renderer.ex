defmodule Billboard.Test.TextRenderer do
  @moduledoc "Draws the shop's Text: its words, in a paragraph, as plain text."
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <p>{@content.body}</p>
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
