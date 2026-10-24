defmodule Billboard.Renderer do
  @moduledoc """
  A component's look: the module its `component` section names as its
  `renderer`. `use Billboard.Renderer` makes a module of function
  components, with the pieces stock sections are drawn from at hand:
  `Billboard.Sections.Parts`, `Words`, `Blocks`, `Glyph`, and
  `EditorFields` aliased, `Billboard.Sections.Buttons` imported, and
  `Phoenix.LiveView.JS` aliased.

      defmodule MySiteWeb.Sections.Faq do
        use Billboard.Renderer

        def render(assigns) do
          ~H\"\"\"
          <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
            <Parts.head head={@content.head} ctx={@ctx} prefix={@anchor} />
          </section>
          \"\"\"
        end

        def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
      end

  `render/1` draws a section, given `section`, its `content` as it's
  drawn (with values the site has stopped offering drawn as its
  defaults), its `anchor`, the DOM id of its outer element, and `ctx`.
  `glyph/1` draws a small sketch of it for the palette, given `section`,
  `content`, and `library`. `empty?/3`, if it has one, says whether a
  section draws nothing for a visitor, given its content, its data, and
  `ctx`, so the editor can draw a stand-in in its place, and
  `nothing_to_show/2`, given its content and `ctx`, says why, after
  "Nothing to show yet:", as in "there are no published reviews.".
  `Billboard.Sections.page/1` asks both.

  The hero component's renderer draws the page's hero block instead of a
  section in `<main>`: its `render/1` draws the block's inside, given
  `section`, `content`, `anchor`, and `ctx`, as any section's is. The
  page keeps the block's outer element, `<section id="page-hero"
  class="bb-section-pad">`, round it on every page, with the editor's
  marks, so the hero opens, shows its issues, and holds its editor as
  any section does. A site's own `:hero` therefore draws its own block,
  starting inside that element: it draws no `id={@anchor}` (the page's
  id is already there), no `Parts.section_class/1`, and no
  `@ctx.surface`, since its `ctx` has no surface (the layout's hero slot
  gives the block one). Start with an element of `bb-wrap` for the
  page's width:

      def render(assigns) do
        ~H\"\"\"
        <div class="bb-wrap">
          <h1 id="main" tabindex="-1" class="bb-title bb-type-title text-bb-title">
            {Words.text(@ctx, "heading", @content.heading)}
          </h1>
        </div>
        \"\"\"
      end

  Its component says `surface_from :layout`, as the stock hero's does,
  or the editor offers a Ground setting the page never draws.
  `heading` and `lede` are the page's, for a version with no hero, such
  as the shared library: then the stock renderer draws them, whatever
  the site's hero.
  If the site's layout has a skip link to `#main`, its hero keeps an
  element with `id="main"` and `tabindex="-1"` for it, as the stock one
  does on the H1's column.

  A stock renderer draws only through billboard's theme (`theme.css`):
  its colours, type, corners, and measures. A site's may use any class.
  """

  @doc "Draws a section."
  @callback render(map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Draws a section's sketch for the palette."
  @callback glyph(map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Whether the section draws nothing for a visitor."
  @callback empty?(content :: struct(), data :: term(), ctx :: map()) :: boolean()

  @doc ~S|Why the section draws nothing, after "Nothing to show yet:", for the editor's stand-in.|
  @callback nothing_to_show(content :: struct(), ctx :: map()) :: String.t()

  @optional_callbacks empty?: 3, nothing_to_show: 2

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Component
      @behaviour Billboard.Renderer

      import Billboard.Sections.Buttons, warn: false

      alias Billboard.Sections.{Blocks, EditorFields, Glyph, Parts, Words}, warn: false
      alias Phoenix.LiveView.JS, warn: false
    end
  end

  @doc """
  The renderer of the component `type`. Raises, naming the fix, when the
  component names none.
  """
  @spec for!(atom()) :: module()
  def for!(type) do
    component = Billboard.Site.component!(type)

    case Billboard.Component.Info.component_renderer(component) do
      {:ok, renderer} when is_atom(renderer) and not is_nil(renderer) ->
        renderer

      _none ->
        raise ArgumentError,
              "#{inspect(component)} names no renderer. Add `renderer MySiteWeb.Sections.Name` " <>
                "to its `component` section, naming a module that does `use Billboard.Renderer`"
    end
  end
end
