defmodule Billboard.Sections do
  @moduledoc """
  Draws a version as a page, in the site's layout (`Billboard.Layout`):
  the hero section as the hero block, in the layout's hero slot, drawn
  by the hero component's renderer, and every other section in order in
  its inner block, in `<main>`.

  Each component names its renderer (`Billboard.Renderer`) in its
  `component` section, with `render/1` (the section) and `glyph/1` (a
  small drawing of its shape, for the page editor's palette), and
  declares how the admin edits it in its `editor` section. Billboard's
  stock components name billboard's renderers (`Billboard.Sections.*`),
  and a site's own components name its own.

  A section's `render/1` takes `section`, its `content` (the component
  struct, as it's drawn: `drawn_content/1`), its `anchor` (the DOM id for
  its outer element), and `ctx`.
  `ctx` carries what sections read besides their own content:

    * `:data`, from `Billboard.Resolver`, by section key. Read it with
      `ctx.data[section.key]`: sections with no data have no entry.
    * `:site`, the site's own data, the `site` the page is given, which
      only the site's own sections and actions read. Stock sections never
      read it.
    * `:version`, the version being rendered, for a section that reads
      another.
    * `:context`, what the page is about, as the site's
      `Billboard.Context` gives it: a page's `:scope` and the hero's
      `:bindings`, and anything else the site's own sections read. Empty
      on a page about nothing in particular.
    * `:state`, the page's own state, such as a filter's, which only the
      site's own sections read. Empty elsewhere.
    * `:surface`, the name of the surface the section is drawn on
      (`surface/2`), and `:joined`, whether it shares its padding with the
      section before it. `section/1` sets both, and `Parts.section_class/1`
      draws them.
    * `:edit`, set only in the page editor: which section is open
      (`open`, its key), the worst issue each section has (`issues`, by
      key), the open section's editor's assigns (`editor`: `page`,
      `actor`, `choices`, `library`, `editor_path`, every issue the page
      has, as `issues`, which of Remove, Up, and Down the open section
      has, as `moves`, the Two columns holding it, if it's a column's, as
      `parent`, and the pages that place each library section, as
      `uses`), and where sections can be added (`add`, for
      `Billboard.EditorLive.Palette.gap/1`, or nil on a fixed page). With
      it, `section/1` and `page/1` put the section being drawn in `ctx` as
      `:section`.

  In the editor, `section/1` wraps each section in an element the admin
  clicks to open it (`#edit-<key>`, with `data-edit-section`), which
  marks a section with an issue and, while it's open, holds its editor
  (`Billboard.EditorLive.SectionEditor`). The hero gets the same from
  `page/1`, on the `<section id="page-hero">` it draws round the hero
  block. A section that would draw nothing, such as reviews with none
  published, is drawn in the editor as a stand-in saying so (its
  renderer's `nothing_to_show/2`), so it can still be opened. A Shared
  section's library section is drawn as a visitor sees it, inside the
  Shared section's wrapper: it is edited in the library. Between the
  sections in `<main>`, `page/1` draws the places a section can be
  added, each opening the palette there.

  The renderers draw a section's words through
  `Billboard.Sections.Words.text/4`, with each field's words path
  (`"head.heading"`, `"points.1.body"`): as visitors always saw them, or,
  in the open section, as a field the editor types into. In the open
  section, a renderer also draws the optional words a visitor wouldn't
  see while they're empty, such as an eyebrow, so they can be typed
  into; `Words.editing?/1` says when.

  Each section is drawn on a surface (`Billboard.Surfaces`), its outer
  element carrying `page-section`, the surface's `bb-surface-NAME`, and
  `data-surface`. Neighbours on one surface share one rhythm: `page/1`
  marks a section `bb-joined` when the section drawn before it in `<main>`
  is on the same surface, and billboard's `theme.css` drops a joined
  section's top padding, so they sit one padding apart, not two. The page
  marks it, since CSS can't compare two sections' surfaces. A stand-out
  section, such as a band, never joins, nor does the section after it:
  each stand-out is meant to stand alone.
  """
  use Phoenix.Component

  alias Billboard.{Catalogue, Renderer, SiteOptions, Surfaces}
  alias Billboard.EditorLive.{Palette, SectionEditor}
  alias Billboard.Sections.{Hero, Parts, Shared, Words}
  alias Phoenix.LiveView.JS

  @doc """
  The components whose sections can draw nothing for their data: those
  whose renderer has `empty?(content, data, ctx)`, which its `render/1`
  asks.
  """
  @spec emptiable() :: [atom()]
  def emptiable, do: for(type <- Catalogue.keys(), emptiable?(Renderer.for!(type)), do: type)

  @doc """
  Whether `section` draws nothing in `ctx`: its renderer's `empty?/3`,
  with its data, for a component that can.
  """
  @spec empty?(map(), map()) :: boolean()
  def empty?(section, ctx) do
    module = Renderer.for!(section.content.type)

    emptiable?(module) and
      module.empty?(drawn_content(section), get_in(ctx, [:data, section.key]), ctx)
  end

  defp emptiable?(module), do: exports?(module, :empty?, 3)

  defp exports?(module, name, arity),
    do: Code.ensure_loaded?(module) and function_exported?(module, name, arity)

  # What a stand-in says, after "Nothing to show yet:": the renderer's
  # words, or, for one that doesn't say, that it draws nothing here.
  defp nothing_to_show(module, content, ctx) do
    if exports?(module, :nothing_to_show, 2),
      do: module.nothing_to_show(content, ctx),
      else: "it draws nothing on this page."
  end

  @doc """
  The component struct `section` is drawn with: its content, with each
  value the site has stopped offering drawn as the site's default
  (`Billboard.SiteOptions.resolved/2`). It's for drawing only: the
  section keeps the value it holds, and the editor shows that one.
  """
  @spec drawn_content(map()) :: struct()
  def drawn_content(%{content: %{type: type, value: content}}),
    do: SiteOptions.resolved(type, content)

  @doc """
  The page: the version's hero, drawn as the hero block, and its other
  sections, handed to the site's layout (`Billboard.Layout`'s `page/1`)
  as its hero slot and its inner block. The page draws the block's
  `<section id="page-hero">`, with the editor's marks, and the hero
  component's renderer draws what's inside it (`Billboard.Renderer`), so
  a site's own `:hero` draws its own. A hero anywhere but first draws
  nothing.

  `site` is the site's own data, which the layout draws from, and its
  own sections read as `ctx.site`. `ctx` holds the page's `:context` and
  `:state` (see the moduledoc); `data`, and `site` as `:site`, are added
  to it here, and the `library` version's sections as `:shared`, by key,
  for the page's Shared sections; without a `library`, they read the
  live library.

  `editing` is set by the page editor in both its modes, and with an
  `:edit` ctx: the layout then draws no messages and nothing that would
  sit over the page, since the editor draws its own bar and messages.

  A version with no hero, as the shared library has, draws `heading` and
  `lede` in the stock hero's place, if given, whatever the site's hero.
  """
  attr :version, :map, required: true
  attr :data, :map, default: %{}
  attr :library, :map, default: nil
  attr :ctx, :map, default: %{}
  attr :flash, :map, required: true

  attr :site, :map, required: true, doc: "the site's own data, for its layout and sections"

  attr :current_path, :string, default: nil
  attr :editing, :boolean, default: false
  attr :heading, :any, default: nil, doc: "the H1 of a version with no hero"
  attr :lede, :any, default: nil, doc: "the opening lines of a version with no hero"

  def page(assigns) do
    {hero, body} =
      case assigns.version.sections do
        [%{content: %{type: :hero}} = hero | body] -> {hero, body}
        body -> {nil, body}
      end

    ctx =
      Map.merge(
        %{
          site: assigns.site,
          data: assigns.data,
          version: assigns.version,
          context: %{},
          state: %{}
        },
        assigns.ctx
      )
      |> put_shared(assigns.library)

    edit = ctx[:edit]
    body = Enum.zip(body, joins(body, ctx, edit != nil))

    assigns =
      assign(assigns,
        editing: assigns.editing or edit != nil,
        edit: edit,
        hero_attrs: hero_attrs(hero, edit),
        hero: hero,
        body: body,
        ctx: ctx,
        hero_ctx: put_section(ctx, hero),
        # The hero's renderer draws what the site offers; the editor's
        # marks keep the section as it's stored.
        hero_content: hero && drawn_content(hero),
        add: edit && edit[:add],
        # Where a section added before the first in `<main>` goes: after
        # the hero.
        first_at: if(hero, do: 1, else: 0)
      )

    ~H"""
    <.site_layout flash={@flash} site={@site} current_path={@current_path} editing={@editing}>
      <:hero>
        <section id="page-hero" class="bb-section-pad" {@hero_attrs}>
          <.edit_marks :if={@edit && @hero} section={@hero} edit={@edit} />
          <.hero_block
            section={@hero}
            content={@hero_content}
            anchor="page-hero"
            ctx={@hero_ctx}
            heading={@heading}
            lede={@lede}
          />
        </section>
      </:hero>

      <%= if @add do %>
        <Palette.gap at={@first_at} add={@add} />
        <%= for {{section, joined?}, i} <- Enum.with_index(@body, @first_at + 1) do %>
          <.section section={section} ctx={@ctx} joined={joined?} />
          <Palette.gap at={i} add={@add} />
        <% end %>
      <% else %>
        <.section :for={{section, joined?} <- @body} section={section} ctx={@ctx} joined={joined?} />
      <% end %>
    </.site_layout>
    """
  end

  # The inside of the hero block: the hero component's renderer draws
  # it, so a site's own `:hero` draws its own. A version with no hero, as
  # the library is, draws its heading and lede in the stock block.
  defp hero_block(%{section: nil} = assigns), do: Hero.render(assigns)
  defp hero_block(assigns), do: Renderer.for!(:hero).render(assigns)

  # The site's layout (`Billboard.Layout`), called through a function
  # component of this module's, so HEEx hands it the slots this template
  # writes and the assigns as they are, with what changed. Change
  # tracking holds through it: a change to the page doesn't resend the
  # layout's header. Assigns built afresh, without `__changed__`, would
  # redraw the whole layout on every change.
  defp site_layout(assigns), do: Billboard.Layout.module!().page(assigns)

  # Whether each of the body's sections is on the same surface as the
  # section drawn before it in `<main>`, so it shares its padding. A
  # visitor's page leaves out a section that draws nothing, and its
  # neighbours meet across it. The editor draws every section in a wrapper
  # of its own, as itself or as a stand-in, so a section's neighbour is
  # always the one before it, and a wrapper with no section in it, as a
  # misplaced hero's, parts the two either side. The first section
  # follows the hero, or the heading of a page with none, outside
  # `<main>`, so it never joins.
  #
  # A stand-out section, such as a band, keeps its own padding, and the
  # section after it keeps its own too: each stand-out is meant to stand
  # alone. Nothing else keeps two bands apart where they can touch, as on
  # the library page, or across a section that draws nothing.
  defp joins(body, ctx, editing?) do
    {joins, _before} =
      Enum.map_reduce(body, nil, fn section, before ->
        drawn = drawn_surface(section, ctx, editing?)

        cond do
          drawn == nil and not editing? -> {false, before}
          stands_out?(section, ctx) -> {false, nil}
          true -> {drawn != nil and drawn == before, drawn}
        end
      end)

    joins
  end

  # The surface of the section `section/1` draws in `<main>`, or nil when
  # it draws none there.
  defp drawn_surface(section, ctx, editing?) do
    if !editing? and empty?(section, ctx), do: nil, else: surface(section, ctx)
  end

  # Whether what `section/1` draws for `section` is a stand-out section: a
  # Shared section is what its library section is.
  defp stands_out?(%{content: %{type: :shared, value: %{key: key}}}, ctx) do
    case Shared.source(ctx, key) do
      nil -> false
      library -> stands_out?(library, ctx)
    end
  end

  defp stands_out?(section, _ctx), do: Surfaces.kind(section.content.type) == :stand_out

  defp put_shared(ctx, nil), do: ctx

  defp put_shared(ctx, library),
    do: Map.put(ctx, :shared, Map.new(library.sections, &{&1.key, &1}))

  # The hero's side of what `section/1` does for the others: the editor
  # marks and opens it by its own `<section>`.
  defp hero_attrs(nil, _edit), do: %{}
  defp hero_attrs(_hero, nil), do: %{}

  defp hero_attrs(hero, edit) do
    open? = edit.open == hero.key

    %{
      "data-edit-section" => hero.key,
      "data-open" => to_string(open?),
      "data-issue" => issue(edit, hero),
      "phx-click" => !open? && open_section(hero)
    }
  end

  @doc """
  One section, drawn by its component's renderer. In the editor, it is
  wrapped to be clicked open (see the moduledoc).

  It puts the section's surface in `ctx` as `:surface` (`surface/2`), and
  `joined` as `:joined`. Only `page/1` knows what the section follows, so
  a section drawn inside another, such as a column, is never joined; a
  Shared section passes its own on to the library section it draws.
  """
  attr :section, :map, required: true
  attr :ctx, :map, required: true
  attr :joined, :boolean, default: false, doc: "on the same surface as the section before it"

  def section(assigns) do
    %{section: section, ctx: ctx} = assigns
    module = Renderer.for!(section.content.type)

    ctx =
      ctx
      |> put_section(section)
      |> Map.merge(%{surface: surface(section, ctx), joined: assigns.joined})

    assigns =
      assigns
      |> assign(:content, drawn_content(section))
      |> assign(:anchor, anchor(section))
      |> assign(:ctx, ctx)

    case assigns.ctx[:edit] do
      nil -> draw(assigns, module)
      edit -> editable(assigns, module, edit)
    end
  end

  # The hero's renderer draws the page's hero block (`page/1`), never a
  # section in `<main>`: a hero anywhere but first draws nothing there.
  defp draw(%{section: %{content: %{type: :hero}}} = assigns, _module), do: ~H""
  defp draw(assigns, module), do: module.render(assigns)

  # The section in its wrapper. A section with nothing to show for its
  # data is drawn as a stand-in, with its head and introduction, so it can
  # be opened and they typed into.
  defp editable(assigns, module, edit) do
    %{section: section, ctx: ctx} = assigns
    type = section.content.type

    nothing? = empty?(section, ctx)

    open? = edit.open == section.key
    # A click inside an open column belongs to the column, not to the
    # closed Two columns around it.
    holds_open? =
      is_list(section.children) and Enum.any?(section.children, &(&1.key == edit.open))

    assigns =
      assign(assigns,
        holds_open?: holds_open?,
        inner: if(!nothing?, do: draw(assigns, module)),
        nothing: if(nothing?, do: nothing_to_show(module, assigns.content, ctx)),
        label: Catalogue.label(type),
        edit: edit,
        open?: open?,
        issue: issue(edit, section)
      )

    ~H"""
    <div
      id={"edit-#{@section.key}"}
      data-edit-section={@section.key}
      data-open={to_string(@open?)}
      data-issue={@issue}
      class={["bb-edit-section", @open? && "is-open"]}
      phx-click={!@open? && !@holds_open? && open_section(@section)}
    >
      <.edit_marks section={@section} edit={@edit} />
      <%= if @nothing do %>
        <section
          id={@anchor}
          data-surface={@ctx.surface}
          class={["bb-edit-stand-in" | Parts.section_class(@ctx)]}
        >
          <Parts.head head={Map.get(@content, :head)} ctx={@ctx} prefix={@anchor} />
          <p
            :if={Map.has_key?(@content, :intro) && (@content.intro || Words.editing?(@ctx))}
            class="bb-type-body bb-measure mb-12 text-bb-ink"
          >
            {Words.text(@ctx, "intro", @content.intro, placeholder: "Introduction (optional)")}
          </p>
          <p class="bb-edit-type-small border border-dashed border-bb-edit-faint px-4 py-6 text-bb-edit-soft">
            {@label} · Nothing to show yet: {@nothing}
          </p>
        </section>
      <% else %>
        {@inner}
      <% end %>
    </div>
    """
  end

  attr :section, :map, required: true
  attr :edit, :map, required: true

  # What the editor draws on a section: its editor while it's open, and
  # otherwise a label that opens it, shown on hover and on keyboard focus,
  # and a "!" for an issue, which the open section's editor lists instead.
  # The label is a button, and marked as the editor's own, so the keyboard
  # can open a section too.
  defp edit_marks(assigns) do
    %{section: section, edit: edit} = assigns

    assigns =
      assign(assigns,
        open?: edit.open == section.key,
        issue: issue(edit, section),
        label: Catalogue.label(section.content.type),
        editor: Map.get(edit, :editor)
      )

    ~H"""
    <.live_component
      :if={@open? && @editor}
      module={SectionEditor}
      id="section-editor"
      section={@section}
      page={@editor.page}
      actor={@editor.actor}
      choices={@editor.choices}
      editor_path={@editor.editor_path}
      library={@editor.library}
      issues={for issue <- Map.get(@editor, :issues, []), issue.key == @section.key, do: issue}
      moves={Map.get(@editor, :moves, %{})}
      parent={Map.get(@editor, :parent)}
      uses={Map.get(@editor, :uses, %{})}
    />
    <button
      :if={!@open?}
      id={"open-#{@section.key}"}
      type="button"
      class="bb-edit-section-tag"
      data-editor-ui
      phx-click={open_section(@section)}
    >
      {issue_words(@issue)}{@label} · Click to edit
    </button>
    <span :if={@issue && !@open?} class="bb-edit-section-issue" data-level={@issue} aria-hidden="true">
      !
    </span>
    """
  end

  defp issue_words(:error), do: "Needs fixing · "
  defp issue_words(:warning), do: "Worth a look · "
  defp issue_words(nil), do: nil

  defp issue(edit, section), do: edit |> Map.get(:issues, %{}) |> Map.get(section.key)

  defp open_section(section), do: JS.push("open_section", value: %{key: section.key})

  # In the editor, the section being drawn, for `Billboard.Sections.Words`
  # to tell whether it's the open one and to find its words' specs.
  defp put_section(%{edit: edit} = ctx, section) when not is_nil(edit) and not is_nil(section),
    do: Map.put(ctx, :section, section)

  defp put_section(ctx, _section), do: ctx

  @doc """
  The name of the surface `section` is drawn on (`Billboard.Surfaces`), in
  `ctx`: the one it records, or its kind's default when it records none,
  or one the site no longer offers it (`Surfaces.resolve/2`).

  Some sections never choose (`Surfaces.taken_from/2`). A column, drawn
  inside Two columns, takes its parent's, which `ctx` holds as
  `:surface`, and a Shared section its library section's, or a page
  section's default when its library section has gone. The hero is drawn
  in the layout's hero slot, on a surface of the layout's, so it has
  none here.
  """
  @spec surface(map(), map()) :: String.t() | nil
  def surface(section, ctx) do
    %{type: type, value: content} = section.content

    case taken_from(section, ctx) do
      nil ->
        Surfaces.resolve(type, Map.get(section, :surface))

      :parent ->
        ctx[:surface] || Surfaces.resolve(type, nil)

      :library ->
        case Shared.source(ctx, content.key) do
          nil -> Surfaces.resolve(type, nil)
          library -> surface(library, ctx)
        end

      :layout ->
        nil
    end
  end

  # A section drawn in a column takes its parent's surface, whether or not
  # it was built with its parent's id, as a starter page's are.
  defp taken_from(section, ctx) do
    if ctx[:in_column],
      do: :parent,
      else: Surfaces.taken_from(section.content.type, Map.get(section, :parent_id))
  end

  @doc """
  The section's glyph: a small drawing of its shape, by its component's
  renderer, as the page editor's palette shows it. As with `render/1`,
  the renderer gets the section's drawn content (`drawn_content/1`). It
  sits in a span naming its component and variant (`data-component`,
  `data-variant`) and fills the space it's given.

  `library` holds the shared library's sections, by key, for a Shared
  section to draw the one it places; without it, the live library's.
  """
  attr :section, :map, required: true
  attr :library, :map, default: nil
  attr :class, :any, default: nil

  def glyph(assigns) do
    type = assigns.section.content.type
    content = drawn_content(assigns.section)

    assigns =
      assign(assigns,
        type: type,
        content: content,
        variant: Map.get(content, :variant),
        module: Renderer.for!(type)
      )

    ~H"""
    <span data-component={@type} data-variant={@variant} class={["flex min-w-0", @class]}>
      <.module_glyph module={@module} section={@section} content={@content} library={@library} />
    </span>
    """
  end

  defp module_glyph(assigns), do: assigns.module.glyph(assigns)

  @doc """
  The section's DOM id: its anchor, or one made from its key.
  """
  @spec anchor(map()) :: String.t()
  defdelegate anchor(section), to: Billboard.Section, as: :dom_id
end
