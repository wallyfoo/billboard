defmodule Billboard.Test.Render do
  @moduledoc """
  Draws one section with its component's renderer, as a visitor sees it
  or open in the editor, without a page around it. `ctx` merges over a
  page's: no data, context, or state, on the site's first surface.
  """
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Billboard.SiteOptions

  @doc "A section of `type`, built from `attrs`, with key `key`."
  def section(type, attrs \\ %{}, key \\ "s1"),
    do: %{
      key: key,
      anchor: nil,
      surface: nil,
      parent_id: nil,
      children: [],
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)}
    }

  @doc "The section as a visitor sees it, as HTML."
  def visitor(section, ctx \\ %{}), do: draw(section, Map.merge(base(), ctx))

  @doc """
  The section open in the editor, as HTML: its words typed into and its
  parts' tools drawn. `ctx` may hold the editor's `choices`, by name.
  """
  def open(section, ctx \\ %{}) do
    {choices, ctx} = Map.pop(ctx, :choices, %{})

    edit = %{open: section.key, issues: %{}, editor: %{choices: choices}}
    draw(section, base() |> Map.merge(ctx) |> Map.merge(%{edit: edit, section: section}))
  end

  @doc "The section's glyph, as HTML."
  def glyph(section) do
    renderer = Billboard.Renderer.for!(section.content.type)
    render_component(&renderer.glyph/1, section: section, content: drawn(section), library: nil)
  end

  defp draw(section, ctx) do
    renderer = Billboard.Renderer.for!(section.content.type)

    render_component(&renderer.render/1,
      section: section,
      content: drawn(section),
      anchor: "section-#{section.key}",
      ctx: ctx
    )
  end

  defp drawn(%{content: %{type: type, value: value}}), do: SiteOptions.resolved(type, value)

  defp base,
    do: %{
      data: %{},
      context: %{},
      state: %{},
      site: %{},
      surface: hd(Billboard.Surfaces.all()).name,
      joined: false
    }
end
