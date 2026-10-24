defmodule Billboard.Test.NotesRenderer do
  @moduledoc "Draws the shop's Notes: each question and its answer, typed in place, in a list."
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <ul>
        <li :for={{item, i} <- Enum.with_index(@content.items)}>
          {Words.text(@ctx, "items.#{i}.title", item.title)}
          {Words.text(@ctx, "items.#{i}.body", item.body)}
        </li>
      </ul>
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
