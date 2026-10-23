defmodule Billboard.Sections.Parts do
  @moduledoc """
  Pieces shared by the section renderers: a section's classes, the
  editable wrapper round `Blocks.section_head/1`, a quote, and actions;
  and the parts drawn from data, such as a news post, an empty state,
  and a footnote. The larger pieces stock sections are drawn from are in
  `Billboard.Sections.Blocks`.

  An action (`Billboard.Parts.Action`) is drawn by its kind, in the
  colours the surface it sits on sets. A link is billboard's; every
  other kind is the site's (`Billboard.Actions`), and one it no longer
  offers draws nothing. Its style picks a primary button, a secondary
  button, or a text link.

  Each part a site may want to decorate carries a hook class: `bb-title`
  on the hero's heading, `bb-eyebrow` on every eyebrow, `bb-heading` on a
  section head's or a band's heading, `bb-section-head` on a section
  head's wrapper, `bb-point` on each point, `bb-detail` on each detail's
  row, `bb-item-title` on a point's, a detail's, or a news post's title,
  `bb-quote` on a quote, `bb-photo` on a photograph, and `bb-button` and
  `bb-link` on a button and a text link. The hooks carry no styles, and
  no stylesheet defines them, so a site can decorate through them in its
  own CSS without replacing a component. The hero's are drawn in the
  page's hero block, a point's and a detail's in their sections, the
  quote and a news post's title here, a button's and a link's in
  `Billboard.Sections.Buttons`, and the rest in `Billboard.Sections.Blocks`.
  """
  use Phoenix.Component

  import Billboard.Sections.Buttons

  alias Billboard.{Format, Markdown}
  alias Billboard.Sections.{Blocks, Icons, Words}
  alias Phoenix.LiveView.JS

  @doc """
  The classes of a section's outer element, from `ctx`: `page-section`,
  the class of the surface it's drawn on, `bb-surface-NAME`, and the page
  margin and padding, `bb-wrap` and `bb-section-pad`. A section on the
  same surface as the one before it (`ctx.joined`) is marked `bb-joined`,
  and `theme.css` drops its top padding. Inside a Two columns
  section, the columns section carries the margin and the padding, so its
  sections leave them out; they're never joined, since each sits apart
  in a column.

  These are classes only. The caller puts `data-surface={@ctx.surface}`
  on the same element, beside them, since some callers add classes of
  their own or pass these to a component that takes a `class`.
  """
  @spec section_class(map()) :: list()
  def section_class(ctx) do
    [
      "page-section",
      "bb-surface-#{Map.fetch!(ctx, :surface)}",
      !ctx[:in_column] && "bb-wrap bb-section-pad",
      ctx[:joined] && "bb-joined"
    ]
  end

  @doc """
  A section's head (`Billboard.Parts.Head`): the hairline, an optional
  eyebrow, the heading, and its one action opposite. Nothing when the
  section has no head. Its words are drawn through
  `Billboard.Sections.Words`, at `path` (`"head.heading"`); in the open
  section, an empty eyebrow is drawn too, to be typed into, its action is
  the editor's to change (`editable_action/1`), and a head without one
  offers to add one.
  """
  attr :head, :map, default: nil
  attr :ctx, :map, required: true
  attr :prefix, :string, default: nil, doc: "names the action's id, such as `<prefix>-book`"
  attr :path, :string, default: "head", doc: "the head's words path in the section's content"

  def head(%{head: nil} = assigns), do: ~H""

  def head(assigns) do
    ~H"""
    <Blocks.section_head
      eyebrow={
        if(@head.eyebrow || Words.editing?(@ctx),
          do: Words.text(@ctx, "#{@path}.eyebrow", @head.eyebrow, placeholder: "Eyebrow (optional)")
        )
      }
      heading={Words.text(@ctx, "#{@path}.heading", @head.heading)}
    >
      <:action :if={@head.action || Words.editing?(@ctx)}>
        <.editable_action :if={@head.action} ctx={@ctx} path={"#{@path}.action"}>
          <.action action={@head.action} ctx={@ctx} prefix={@prefix} />
        </.editable_action>
        <.add_button :if={!@head.action} path={"#{@path}.action"} />
      </:action>
    </Blocks.section_head>
    """
  end

  @doc """
  A named quote at quote size, in the heading face, with a caps
  attribution: who said it, and a line about them. Its words take the
  heading's ink, and its name the subheading's, so a band's quote reads as
  the band sets them. `body_class` and `caption_class` set the quote's
  size and the attribution's spacing, for quotes set smaller than a
  band's. It isn't called `quote/1`, which `Kernel.SpecialForms` already
  defines.
  """
  attr :name, :any, default: nil, doc: "a string, or the editor's words"
  attr :meta, :any, default: nil, doc: "a string, or the editor's words"
  attr :class, :any, default: nil
  attr :body_class, :any, default: "bb-type-quote max-w-[30ch]"
  attr :caption_class, :any, default: "mt-6"
  attr :rest, :global
  slot :inner_block, required: true

  def quote_figure(assigns) do
    ~H"""
    <figure class={@class} {@rest}>
      <blockquote class={["bb-quote", @body_class, "text-bb-heading"]}>
        {render_slot(@inner_block)}
      </blockquote>
      <figcaption
        :if={@name || @meta}
        class={["bb-type-label flex gap-3", @caption_class, "text-bb-ink-soft"]}
      >
        <span :if={@name} class="text-bb-subheading">
          {@name}
        </span>
        <span :if={@meta}>{@meta}</span>
      </figcaption>
    </figure>
    """
  end

  @doc """
  A row of actions. The hero doesn't use it: the page's hero block
  already lays the hero's actions out in a row. In the open section,
  each one is the editor's to change (`editable_action/1`), at `path`
  and its place, and another can be added while there are fewer than
  `max`.
  """
  attr :actions, :list, required: true
  attr :ctx, :map, required: true
  attr :prefix, :string, default: nil, doc: "names the actions' ids, such as `<prefix>-book`"
  attr :class, :any, default: nil
  attr :path, :string, default: "actions", doc: "the actions' path in the section's content"
  attr :max, :integer, default: nil, doc: "the most actions the section takes"

  def action_group(assigns) do
    assigns =
      assign(assigns,
        add?:
          Words.editing?(assigns.ctx) and is_integer(assigns.max) and
            length(assigns.actions) < assigns.max
      )

    ~H"""
    <div class={["flex flex-wrap items-center gap-4", @class]}>
      <.editable_action
        :for={{action, i} <- Enum.with_index(@actions)}
        ctx={@ctx}
        path={"#{@path}.#{i}"}
      >
        <.action action={action} ctx={@ctx} prefix={@prefix} />
      </.editable_action>
      <.add_button :if={@add?} path={@path} />
    </div>
    """
  end

  @doc """
  A button, an action or a point's link, at `path` in the section's
  content (`"actions.1"`, `"head.action"`, `"points.0.link"`). For a
  visitor, and in a section the editor hasn't opened, it is the button
  alone. In the open section, it is marked with its path
  (`data-edit-action`), so a click on it opens its popover in the
  section's editor instead of following it (the canvas's hook, or this
  mark's own click without it), and as the editor's own
  (`data-editor-ui`). The mark takes no room (`display: contents`).
  """
  attr :ctx, :map, required: true
  attr :path, :string, required: true
  slot :inner_block, required: true

  def editable_action(assigns) do
    assigns = assign(assigns, :editing?, Words.editing?(assigns.ctx))

    ~H"""
    <%= if @editing? do %>
      <span
        id={"section-at-#{Words.dashed(@path)}"}
        class="bb-edit-action"
        data-edit-action={@path}
        data-editor-ui
        phx-click={JS.push("edit_action", value: %{path: @path}, target: "#section-editor")}
      >
        {render_slot(@inner_block)}
      </span>
    <% else %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end

  @doc """
  In the open section, a way to add a button at `path`: to a list of them
  (`"actions"`), or as a part the section can do without
  (`"head.action"`, `"points.1.link"`). The section's editor adds it and
  opens its popover.
  """
  attr :path, :string, required: true
  attr :words, :string, default: "Add a button"
  attr :class, :any, default: nil

  def add_button(assigns) do
    ~H"""
    <button
      id={"section-add-button-#{Words.dashed(@path)}"}
      type="button"
      class={["bb-edit-add-inline", @class]}
      data-editor-ui
      phx-click={JS.push("add_button", value: %{path: @path}, target: "#section-editor")}
    >
      <span aria-hidden="true">+</span> {@words}
    </button>
    """
  end

  @doc """
  An item's tools in the open section: remove it, unless the list is at
  its fewest (`spec`'s `min`), and move it up or down, in its top right.
  `path` is the list's (`"points"`), `index` the item's place, and
  `count` how many the list has. Anything else the item needs, such as a
  detail's group, goes in the slot, before them. Each goes to the
  section's editor.
  """
  attr :path, :string, required: true
  attr :index, :integer, required: true
  attr :count, :integer, required: true
  attr :spec, :list, required: true, doc: "the list's spec, for its fewest and its items' name"

  def item_tools(assigns) do
    item = assigns.spec[:item_label] || "item"

    assigns =
      assign(assigns,
        id: "section-item-#{assigns.path}-#{assigns.index}",
        name: "#{item} #{assigns.index + 1}",
        removable?: assigns.count > Keyword.get(assigns.spec, :min, 0),
        target: "#section-editor"
      )

    ~H"""
    <div
      id={@id}
      class="bb-edit-item-tools"
      role="group"
      aria-label={String.capitalize(@name)}
      data-editor-ui
    >
      <button
        :if={@removable?}
        id={"#{@id}-remove"}
        type="button"
        aria-label={"Remove #{@name}"}
        title="Remove"
        phx-click={
          JS.push("remove_item", value: %{path: @path, index: @index}, target: @target)
          |> JS.focus(to: "#section-controls")
        }
      >
        <Icons.icon name="hero-x-mark-mini" class="size-4" />
      </button>
      <button
        :for={{dir, show?} <- [{"up", @index > 0}, {"down", @index < @count - 1}]}
        :if={show?}
        id={"#{@id}-#{dir}"}
        type="button"
        aria-label={"Move #{@name} #{dir}"}
        title={"Move #{dir}"}
        phx-click={
          JS.push("move_item", value: %{path: @path, index: @index, dir: dir}, target: @target)
        }
      >
        <%!-- Named in full, for Tailwind to find. --%>
        <Icons.icon
          name={if(dir == "up", do: "hero-arrow-up-mini", else: "hero-arrow-down-mini")}
          class="size-4"
        />
      </button>
    </div>
    """
  end

  @doc """
  A photograph (the slot), and in the open section its tools over it:
  remove it, when there's one; describe it, for the placeholder's words
  and the words read aloud for it; and put one in, or another in its
  place. The section's editor holds the upload's file input, which
  Replace clicks, and saves the photograph once it has arrived.
  """
  attr :ctx, :map, required: true
  attr :photo, :map, default: nil, doc: "the section's photograph, if it has one"
  slot :inner_block, required: true

  def editable_photo(assigns) do
    assigns =
      assign(assigns,
        editing?: Words.editing?(assigns.ctx),
        key: assigns.ctx[:section] && assigns.ctx.section.key,
        has_photo?: present?(assigns.photo && assigns.photo.path)
      )

    ~H"""
    <%= if @editing? do %>
      <div class="relative">
        {render_slot(@inner_block)}
        <div class="bb-edit-photo-tools" role="group" aria-label="Photograph" data-editor-ui>
          <button
            :if={@has_photo?}
            id="section-photo-remove"
            type="button"
            data-confirm="Take this photograph off the section? The placeholder shows in its place."
            phx-click={
              JS.push("remove_photo", target: "#section-editor")
              |> JS.focus(to: "#section-photo-describe")
            }
          >
            Remove
          </button>
          <button
            id="section-photo-describe"
            type="button"
            phx-click={JS.push("describe_photo", target: "#section-editor")}
          >
            Describe
          </button>
          <button
            id="section-photo-replace"
            type="button"
            phx-click={JS.dispatch("click", to: "#photo-form-#{@key} input[type='file']")}
          >
            {if @has_photo?, do: "Replace", else: "Add a photograph"}
          </button>
        </div>
      </div>
    <% else %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end

  @doc "Whether `text` is a string with something in it."
  @spec present?(term()) :: boolean()
  def present?(text), do: is_binary(text) and text != ""

  @doc """
  One action, drawn by its kind, in the colours the surface it sits on
  sets. A link is billboard's; every other kind is the site's
  (`Billboard.Actions`), and one it no longer offers draws nothing.
  `prefix` names the ids a section's actions take, so two sections'
  never clash; the hero's is `"hero"`.
  """
  attr :action, :map, required: true
  attr :ctx, :map, required: true
  attr :prefix, :string, default: nil, doc: "names the actions' ids, such as `<prefix>-book`"

  def action(%{action: %{kind: :link}} = assigns) do
    ~H"""
    <.bb_link :if={@action.style == :text} navigate={@action.path}>
      {@action.label}
    </.bb_link>
    <.bb_button :if={@action.style != :text} variant={variant(@action.style)} navigate={@action.path}>
      {@action.label}
    </.bb_button>
    """
  end

  def action(%{action: %{kind: kind}} = assigns) do
    if Billboard.Actions.offered?(kind),
      do: Billboard.Site.actions().action(assigns),
      else: ~H""
  end

  @doc """
  One news post: its date, title, and words.
  """
  attr :post, :map, required: true

  def news_item(assigns) do
    ~H"""
    <article id={"news-#{@post.id}"}>
      <p class="bb-type-label text-bb-ink-soft">{Format.date(@post.published_on)}</p>
      <%!-- An item title's colour at a heading's size, on purpose. --%>
      <h3 class="bb-item-title bb-type-heading mt-3 text-bb-subheading">{@post.title}</h3>
      <p class="bb-type-body bb-measure mt-3 text-bb-ink">{Markdown.inline(@post.body)}</p>
    </article>
    """
  end

  @doc """
  What a section says when it has nothing to show, in its own words.
  Nothing when it has no words for that.
  """
  attr :text, :string, default: nil
  attr :id, :string, default: nil
  attr :class, :any, default: nil

  def empty_state(%{text: nil} = assigns), do: ~H""

  def empty_state(assigns) do
    ~H"""
    <p id={@id} class={["bb-type-body", @class, "text-bb-ink-soft"]}>{Markdown.inline(@text)}</p>
    """
  end

  @doc """
  A small note under a section's content.
  """
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def footnote(assigns) do
    ~H"""
    <p class={["bb-type-small", @class, "text-bb-ink-soft"]}>{render_slot(@inner_block)}</p>
    """
  end

  ## Editing parts

  @doc """
  How the admin edits a part, as `Billboard.Sections.EditorFields` takes
  it. `:link` is an action that can only be a link, as a point's is.
  `{part, except: fields}` is the part without some of its fields, as a
  component's `editor` section may name it.
  """
  def editor_fields({part, except: fields}), do: Keyword.drop(editor_fields(part), fields)

  def editor_fields(:action) do
    kinds = Billboard.Actions.kinds()
    all = Keyword.keys(kinds)
    site_worded = for {kind, opts} <- kinds, opts[:words] == :site, do: kind

    [
      kind: [
        as: :select,
        label: "Goes to",
        options: for({kind, opts} <- kinds, do: {opts[:label], kind}),
        only_on: for({kind, opts} <- kinds, is_list(opts[:only_on]), do: {kind, opts[:only_on]})
      ],
      style: [
        as: :select,
        label: "Looks like",
        options: [
          {"Primary button", :primary},
          {"Secondary button", :secondary},
          {"Text link", :text}
        ]
      ],
      label: [
        label: "Words",
        limit: 24,
        hint: Billboard.Actions.label_hint(),
        hide_when: [kind: site_worded]
      ],
      path: [
        label: "Address",
        hint: path_hint(),
        hide_when: [kind: all -- [:link]]
      ],
      fixed_words: [
        as: :note,
        text: "The site words this one itself, from its settings.",
        hide_when: [kind: all -- site_worded]
      ]
    ]
  end

  def editor_fields(:link) do
    [
      label: [label: "Link words", limit: 24],
      path: [label: "Address", hint: path_hint()]
    ]
  end

  def editor_fields(:head) do
    [
      eyebrow: [label: "Eyebrow", limit: 30],
      heading: [label: "Heading", limit: 60, accent: true],
      action: [as: :part, part: :action, optional: true, item_label: "action"]
    ]
  end

  def editor_fields(:quote) do
    [
      body: [as: :markdown, label: "Quote", limit: 200],
      name: [label: "Who said it", limit: 30],
      meta: [label: "About them", limit: 30, hint: "Such as when, or for what."]
    ]
  end

  def editor_fields(:point) do
    [
      title: [label: "Title", limit: 40, accent: true],
      body: [as: :markdown, label: "Words", limit: 240],
      link: [as: :part, part: :link, optional: true, item_label: "link"],
      surface: [as: :surface, label: "Ground"]
    ]
  end

  # A photograph is changed by its tools, drawn over it, so it has no
  # fields of its own here.
  def editor_fields(:photo), do: []

  def editor_fields(:detail) do
    [
      label: [label: "Label", limit: 30],
      body: [as: :markdown, label: "Words", limit: 300],
      only_for_group: [as: :choice, from: :scope, label: "Shows on"]
    ]
  end

  @doc """
  What a part holds when the admin adds one, as form params: enough to
  pass its validations, for the admin to write over. The page editor
  warns about any of it left on a page. A part with fields left out
  starts as the part does.
  """
  def blank({part, _opts}), do: blank(part)

  def blank(:action),
    do: %{"kind" => "link", "style" => "secondary", "label" => "Your link", "path" => "/"}

  def blank(:link), do: %{"label" => "Your link", "path" => "/"}
  def blank(:head), do: %{"heading" => "Your heading"}
  def blank(:quote), do: %{"body" => "Your quote"}
  def blank(:point), do: %{"title" => "Your point"}
  def blank(:photo), do: %{"label" => "What the photograph shows"}

  def blank(:detail), do: %{"label" => "Your label", "body" => "What a visitor should know."}

  @doc "The parts `blank/1` knows."
  def parts, do: ~w(action link head quote point photo detail)a

  # An address's hint, with an address on the site.
  defp path_hint, do: "A page on this site, such as #{Billboard.Site.example_path()}"

  defp variant(:primary), do: "primary"
  defp variant(_style), do: "secondary"
end
