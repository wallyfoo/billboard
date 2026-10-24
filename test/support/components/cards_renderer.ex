defmodule Billboard.Test.CardsRenderer do
  @moduledoc "Draws the shop's Cards: its title, as plain text, and each item's, typed in place."
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <h2 :if={@content.head}>{@content.head.title}</h2>
      <p :for={{item, i} <- Enum.with_index(@content.items)}>
        {Words.text(@ctx, "items.#{i}.title", item.title)}
      </p>
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
