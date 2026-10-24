defmodule Billboard.Layout do
  @moduledoc """
  The site's chrome round every page: its header, footer, and anything
  else on every page, in the editor and for visitors. A site names its
  module in `use Billboard.Site`, as `layout: MySiteWeb.Layouts`:

      @behaviour Billboard.Layout

      attr :flash, :map, required: true
      attr :site, :map, required: true
      attr :current_path, :string, default: nil
      attr :editing, :boolean, default: false
      slot :hero, required: true
      slot :inner_block, required: true

      @impl true
      def page(assigns) do
        ~H\"\"\"
        <header>…</header>
        <div class="bb-surface-band">{render_slot(@hero)}</div>
        <main>{render_slot(@inner_block)}</main>
        <footer>…</footer>
        <.flash_group :if={!@editing} flash={@flash} />
        \"\"\"
      end

      @impl true
      def site, do: %{settings: MySite.settings!()}

  `page/1` takes:

    * `hero`, the page's hero block, which takes its surface from the
      layout (`surface_from :layout`), so the layout wraps it in one;
    * `inner_block`, the page's other sections;
    * `site`, the site's own data, as its LiveViews hand it to
      `Billboard.Sections.page/1` and the editor reads it from `site/0`;
    * `current_path`, the address drawn, for the site's menu;
    * `editing`, true in the editor, which draws its own bar and
      messages, so the layout draws no messages and nothing that would
      sit over the page, such as a bar fixed to the screen.

  Billboard calls `page/1` through a function component of its own,
  which hands it the slots it writes and its assigns with what changed,
  so a change to the page redraws only what changed, and resends the
  layout's header or footer only when what they draw has. A layout
  draws the slots with `render_slot/1` where it puts them.
  """

  @doc "Draws the site's chrome round the page's hero block and its sections."
  @callback page(map()) :: Phoenix.LiveView.Rendered.t()

  @doc "The site's own data, which the editor hands `page/1` as `site`."
  @callback site() :: map()

  @optional_callbacks site: 0

  @doc "The site's layout module. Raises, naming the fix, when it names none."
  @spec module!() :: module()
  def module! do
    Billboard.Site.layout() ||
      raise ArgumentError,
            "#{inspect(Billboard.Site.get!())} names no layout. Add `layout: MySiteWeb.Layouts` " <>
              "to its `use Billboard.Site`, a module with `@behaviour Billboard.Layout`"
  end

  @doc "The site's own data, for the editor, or none."
  @spec site() :: map()
  def site do
    module = module!()
    Code.ensure_loaded(module)
    if function_exported?(module, :site, 0), do: module.site(), else: %{}
  end
end
