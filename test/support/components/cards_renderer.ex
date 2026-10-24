defmodule Billboard.Test.CardsRenderer do
  @moduledoc """
  Draws the shop's Cards: its title, as plain text, and each item's,
  typed in place, with its tools in the open section.
  """
  use Billboard.Renderer

  def render(assigns) do
    editing? = Words.editing?(assigns.ctx)

    assigns =
      assign(assigns,
        editing?: editing?,
        count: length(assigns.content.items),
        spec: if(editing?, do: EditorFields.narrowed(:cards)[:items], else: [])
      )

    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <h2 :if={@content.head}>{@content.head.title}</h2>
      <div :for={{item, i} <- Enum.with_index(@content.items)}>
        <p>{Words.text(@ctx, "items.#{i}.title", item.title)}</p>
        <Parts.item_tools :if={@editing?} path="items" index={i} count={@count} spec={@spec} />
      </div>
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
