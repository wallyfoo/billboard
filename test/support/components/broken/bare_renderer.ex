defmodule Billboard.Test.Broken.BareRenderer do
  @moduledoc """
  Draws a section's outer element and nothing in it, for the broken
  components whose checks never draw them.
  """
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}></section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
