defmodule Billboard.Sections.Columns do
  @moduledoc """
  Two columns: the section's two children side by side on wider screens,
  sharing the width evenly (`:even`), or with the left (`:wide_left`) or
  right (`:wide_right`) one wider. The columns section carries the page
  margin and the padding, so its children render with `in_column` set in
  `ctx` and leave out their own. They're drawn on its surface, which
  `ctx` passes on to them.
  """
  use Billboard.Renderer

  alias Billboard.Sections

  @doc "Draws the two columns, each holding its section."
  def render(assigns) do
    assigns = assign(assigns, :column_ctx, Map.put(assigns.ctx, :in_column, true))

    ~H"""
    <section
      id={@anchor}
      data-columns={@content.variant}
      data-surface={@ctx.surface}
      class={
        Parts.section_class(@ctx) ++ ["grid items-start gap-12 md:gap-18", grid(@content.variant)]
      }
    >
      <div :for={child <- @section.children}>
        <Sections.section section={child} ctx={@column_ctx} />
      </div>
    </section>
    """
  end

  defp grid(:even), do: "md:grid-cols-2"
  defp grid(:wide_left), do: "md:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]"
  defp grid(:wide_right), do: "md:grid-cols-[minmax(0,1fr)_minmax(0,1.6fr)]"

  @doc """
  The columns' glyph: two halves, even or one wider
  (`EditorFields.column_widths/1`), each holding its section's glyph.
  """
  def glyph(assigns) do
    assigns =
      assign(
        assigns,
        :columns,
        Enum.zip(assigns.section.children, EditorFields.column_widths(assigns.content.variant))
      )

    ~H"""
    <span class="flex flex-1 gap-1">
      <span
        :for={{child, width} <- @columns}
        class={["flex min-w-0 border border-dashed border-bb-glyph-line p-px", width]}
      >
        <Sections.glyph section={child} library={@library} class="flex-1" />
      </span>
    </span>
    """
  end
end
