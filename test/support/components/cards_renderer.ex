defmodule Billboard.Test.CardsRenderer do
  @moduledoc "Draws the shop's Cards: its title, and each item's, as plain text."
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <h2 :if={@content.head}>{@content.head.title}</h2>
      <p :for={item <- @content.items}>{item.title}</p>
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
