defmodule MySiteWeb.Sections.Fees do
  @moduledoc """
  Draws the fees the page's data holds for this section: every one, or,
  when the section shows only the page's service, those of the service
  the page is about (`ctx.context.scope`), or none on a page about no
  service.
  """
  use Billboard.Renderer

  # guide:render
  def render(assigns) do
    assigns = assign(assigns, fees: fees(assigns.content, assigns.section, assigns.ctx))

    ~H"""
    <section
      :if={@fees != []}
      id={@anchor}
      data-surface={@ctx.surface}
      class={Parts.section_class(@ctx)}
    >
      <h2 class="bb-heading bb-type-heading text-bb-heading">
        {Words.text(@ctx, "title", @content.title)}
      </h2>
      <ul class="bb-measure mt-8">
        <li :for={fee <- @fees} class="bb-rule-top flex justify-between gap-4 py-4">
          <span class="bb-type-body text-bb-ink">{fee.title}</span>
          <span class="bb-type-subheading text-bb-subheading">{fee.price}</span>
        </li>
      </ul>
    </section>
    """
  end

  def empty?(content, data, ctx), do: shown(content, data, ctx) == []

  def nothing_to_show(_content, _ctx), do: "there are no fees to show."

  defp fees(content, section, ctx), do: shown(content, ctx.data[section.key], ctx)

  # With `this_service_only` set, only the fees of the page's service.
  defp shown(%{this_service_only: false}, fees, _ctx), do: fees || []

  defp shown(_content, fees, ctx) do
    scope = get_in(ctx, [:context, :scope])
    Enum.filter(fees || [], &(&1.group == scope))
  end

  # guide:end

  def glyph(assigns) do
    ~H"""
    <span class="grid flex-1 content-center gap-1 px-1">
      <span class="h-1.5 w-1/2 bg-bb-glyph-ink"></span>
      <span :for={_row <- 1..3} class="flex justify-between border-t border-bb-glyph-line pt-1">
        <span class="h-1 w-1/2 bg-bb-glyph-soft"></span>
        <span class="h-1 w-1/6 bg-bb-glyph-ink"></span>
      </span>
    </span>
    """
  end
end
