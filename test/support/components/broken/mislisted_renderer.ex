defmodule Billboard.Test.Broken.MislistedRenderer do
  @moduledoc "Draws `Billboard.Test.Broken.Mislisted`'s questions."
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <p :for={item <- @content.items}>{item.question}</p>
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
