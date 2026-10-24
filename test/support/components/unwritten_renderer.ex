defmodule Billboard.Test.UnwrittenRenderer do
  @moduledoc "Draws the shop's Unwritten: its title typed in place, and its note as plain text."
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <h2>{Words.text(@ctx, "title", @content.title)}</h2>
      <p>{@content.note}</p>
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
