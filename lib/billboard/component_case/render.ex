defmodule Billboard.ComponentCase.Render do
  @moduledoc """
  Draws sections in tests, as a visitor sees them or open in the
  editor, for a site's tests of its own components.
  `Billboard.ComponentCase` uses it; a test may too.

      section = Render.section(:faq, %{title: "Asked", questions: [%{title: "Open late?"}]})
      Render.visitor(section)   # the renderer alone
      Render.open(section)      # its words typed into
      Render.page([section])    # on a page, in the site's layout

  `section/3` builds one from attrs, as the palette would, without
  saving it. `visitor/2` and `open/2` call the component's renderer
  alone, which is quick, but leave out what the page draws round it:
  a hero draws the inside of its block, without the `#page-hero`
  section, its surface, or the layout. `page/2` draws the page.

  Each returns HTML, as a string. It draws with
  `Phoenix.LiveViewTest.render_component/2`, which LiveView compiles in
  every environment, so this module needs nothing a site keeps for its
  tests alone.
  """
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Billboard.SiteOptions

  @doc """
  A section of `type`, built from `attrs`, with key `key`. It isn't
  saved. It's the site's section resource when the site names one, so
  the editor can make a form of it, and a plain map otherwise.
  """
  @spec section(atom(), map(), String.t()) :: map()
  def section(type, attrs \\ %{}, key \\ "s1") do
    fields = %{
      key: key,
      anchor: nil,
      surface: nil,
      parent_id: nil,
      position: 0,
      children: [],
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)}
    }

    case resource(:section) do
      nil -> fields
      resource -> struct(resource, fields)
    end
  end

  @doc """
  The section as a visitor sees it, as HTML. `ctx` merges over a page's:
  no data, context, or state, on the site's first surface.
  """
  @spec visitor(map(), map()) :: String.t()
  def visitor(section, ctx \\ %{}), do: draw(section, Map.merge(base(), ctx))

  @doc """
  The section open in the editor, as HTML: its words typed into and its
  parts' tools drawn. `ctx` merges over a page's, as `visitor/2`'s does,
  and may hold the editor's `choices`, by name.
  """
  @spec open(map(), map()) :: String.t()
  def open(section, ctx \\ %{}) do
    {choices, ctx} = Map.pop(ctx, :choices, %{})

    edit = %{open: section.key, issues: %{}, editor: %{choices: choices}}
    draw(section, base() |> Map.merge(ctx) |> Map.merge(%{edit: edit, section: section}))
  end

  @doc "The section's glyph, the palette's small drawing of it, as HTML."
  @spec glyph(map()) :: String.t()
  def glyph(section) do
    renderer = Billboard.Renderer.for!(section.content.type)
    render_component(&renderer.glyph/1, section: section, content: drawn(section), library: nil)
  end

  @doc """
  `sections` on a page, drawn through `Billboard.Sections.page/1` in the
  site's layout, as a visitor sees them, as HTML. A first section that's
  a hero is drawn as the hero block, in the layout's hero slot.

  Options: `data`, the page's data by section key; `library`, the shared
  library's version, for Shared sections; and `context`, the page's
  context (`Billboard.Context`).
  """
  @spec page([map()], keyword()) :: String.t()
  def page(sections, opts \\ []) do
    render_component(&Billboard.Sections.page/1,
      version: version(sections),
      data: Keyword.get(opts, :data, %{}),
      library: Keyword.get(opts, :library),
      ctx: %{context: Keyword.get(opts, :context, %{})},
      site: Billboard.Layout.site(),
      flash: %{},
      current_path: "/"
    )
  end

  @doc """
  A draft version holding `sections`: the site's version resource when it
  names one, and a plain map otherwise. It isn't saved.
  """
  @spec version([map()]) :: map()
  def version(sections) do
    case resource(:version) do
      nil -> %{status: :draft, sections: sections}
      resource -> struct(resource, status: :draft, sections: sections)
    end
  end

  # The site's resource, or nil on a hand-written site, which defines no
  # `resources/0` (`Billboard.Site.resource!/1` raises for one).
  defp resource(name) do
    site = Billboard.Site.get!()

    if Code.ensure_loaded?(site) and function_exported?(site, :resources, 0),
      do: site.resources()[name]
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
