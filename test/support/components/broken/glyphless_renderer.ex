defmodule Billboard.Test.Broken.GlyphlessRenderer do
  @moduledoc "Draws `Billboard.Test.Broken.Glyphless`'s title, and an empty glyph."
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <h2>{@content.title}</h2>
    </section>
    """
  end

  def glyph(assigns), do: ~H""
end
