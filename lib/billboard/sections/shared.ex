defmodule Billboard.Sections.Shared do
  @moduledoc """
  A section from the shared library, drawn as the library has it: from
  `ctx.shared` when the page passed its library
  (`Billboard.Sections.page/1`), else from the live library
  (`Billboard.Pages.shared_section/1`), with the library section's own
  anchor. Nothing shows when the key has left the library, or when the
  library section is itself a shared section, which could point back at
  itself.

  In the page editor, the library section is drawn as a visitor sees it,
  never opened here: it's edited in the library.

  The library section is drawn on its own surface, never the Shared
  section's, and joins the section before it as the Shared section would.
  """
  use Billboard.Renderer

  alias Billboard.{Pages, Sections}

  @doc "Draws the library section the shared section places."
  def render(assigns) do
    assigns =
      assign(assigns,
        library: source(assigns.ctx, assigns.content.key),
        library_ctx: library_ctx(assigns.ctx)
      )

    ~H"""
    <Sections.section :if={@library} section={@library} ctx={@library_ctx} joined={@ctx.joined} />
    """
  end

  @doc """
  Whether `render/1` draws nothing: the library has no section to draw,
  or the one it has draws nothing here itself (`Sections.empty?/2`), such
  as Details whose every item is for another scope.
  """
  def empty?(content, _data, ctx) do
    case source(ctx, content.key) do
      nil -> true
      library -> Sections.empty?(library, library_ctx(ctx))
    end
  end

  @doc "What the editor's stand-in says when `render/1` draws nothing."
  def nothing_to_show(content, ctx) do
    if source(ctx, content.key),
      do: "its library section has nothing to show on this page.",
      else: "its section has left the shared library."
  end

  @doc """
  The library section the shared section `key` draws, or nil when there's
  none it can draw.
  """
  def source(ctx, key) do
    case shared_section(ctx, key) do
      %{content: %{type: :shared}} -> nil
      section -> section
    end
  end

  defp library_ctx(ctx), do: Map.drop(ctx, [:edit, :section])

  defp shared_section(%{shared: shared}, key) when is_map(shared), do: Map.get(shared, key)
  defp shared_section(_ctx, key), do: Pages.shared_section(key)

  @doc """
  A shared section's glyph: the glyph of the library section it places,
  marked with a link. A dashed outline stands in for a section that has
  left the library.
  """
  def glyph(assigns) do
    source =
      case library_section(assigns[:library], assigns.content.key) do
        %{content: %{type: :shared}} -> nil
        section -> section
      end

    assigns = assign(assigns, :source, source)

    ~H"""
    <span class="relative flex flex-1">
      <Sections.glyph :if={@source} section={@source} class="flex-1" />
      <span :if={!@source} class="flex-1 border border-dashed border-bb-glyph-faint"></span>
      <span class="absolute -top-0.5 -right-0.5 flex size-3.5 items-center justify-center bg-bb-glyph-paper text-bb-glyph-ink">
        <Billboard.Sections.Icons.icon name="hero-link-micro" class="size-3" />
      </span>
    </span>
    """
  end

  defp library_section(library, key) when is_map(library), do: Map.get(library, key)
  defp library_section(_library, key), do: Pages.shared_section(key)
end
