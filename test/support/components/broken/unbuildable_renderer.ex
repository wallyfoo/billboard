defmodule Billboard.Test.Broken.UnbuildableRenderer do
  @moduledoc "Draws `Billboard.Test.Broken.Unbuildable`'s title."
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <h2>{@content.title}</h2>
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
