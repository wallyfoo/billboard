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
  `ctx`, so the editor can draw a stand-in in its place.

  A stock renderer draws only through billboard's theme (`theme.css`):
  its colours, type, corners, and measures. A site's may use any class.
  """

  @doc "Draws a section."
  @callback render(map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Draws a section's sketch for the palette."
  @callback glyph(map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Whether the section draws nothing for a visitor."
  @callback empty?(content :: struct(), data :: term(), ctx :: map()) :: boolean()

  @optional_callbacks empty?: 3

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
