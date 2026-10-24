defmodule Billboard.Test.NotesRenderer do
  @moduledoc """
  Draws the shop's Notes: each question and its answer, typed in place,
  in a list, with each one's tools in the open section.
  """
  use Billboard.Renderer

  def render(assigns) do
    editing? = Words.editing?(assigns.ctx)

    assigns =
      assign(assigns,
        editing?: editing?,
        count: length(assigns.content.items),
        spec: if(editing?, do: EditorFields.narrowed(:notes)[:items], else: [])
      )

    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <ul>
        <li :for={{item, i} <- Enum.with_index(@content.items)}>
          {Words.text(@ctx, "items.#{i}.title", item.title)}
          {Words.text(@ctx, "items.#{i}.body", item.body)}
          <Parts.item_tools :if={@editing?} path="items" index={i} count={@count} spec={@spec} />
        </li>
      </ul>
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
