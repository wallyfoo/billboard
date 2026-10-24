defmodule Billboard.Sections.Details do
  @moduledoc """
  Labelled details under an optional section head. A detail limited to a
  scope (`only_for_group`) shows only where the page's scope
  (`ctx.context.scope`) is that one. A `:narrow` section keeps to
  `35rem`. With no head and no detail to show, the section draws nothing
  at all.

  A detail's words path names its place among all the section's details
  (`items.2.label`), not among those the page shows.

  The open section shows every detail, so each can be changed whichever
  page it's for, with its tools (`Parts.item_tools/1`) and a "Shows on"
  select for its scope; those for another scope are faded, and say so.
  """
  use Billboard.Renderer

  @doc "Draws the details."
  def render(assigns) do
    editing? = Words.editing?(assigns.ctx)

    assigns =
      assign(assigns,
        items: shown(assigns.content, assigns.ctx),
        editing?: editing?,
        scope: page_scope(assigns.ctx),
        choices: editing? && get_in(assigns.ctx, [:edit, :editor, :choices, :scope]),
        # Narrowing reads the site's options, which only the editor needs.
        spec: if(editing?, do: EditorFields.narrowed(:details)[:items], else: []),
        count: length(assigns.content.items)
      )

    ~H"""
    <section
      :if={@content.head || @items != []}
      id={@anchor}
      data-surface={@ctx.surface}
      class={Parts.section_class(@ctx)}
    >
      <.width narrow={@content.width == :narrow}>
        <Parts.head head={@content.head} ctx={@ctx} prefix={@anchor} />
        <.detail_list :if={@items != []}>
          <:item
            :for={{item, i} <- @items}
            title={Words.text(@ctx, "items.#{i}.label", item.label)}
            class={
              @editing? &&
                ["bb-edit-item", item.only_for_group not in [nil, @scope] && "is-elsewhere"]
            }
          >
            {Words.text(@ctx, "items.#{i}.body", item.body)}
            <.shows_on
              :if={@choices}
              index={i}
              value={item.only_for_group}
              here?={item.only_for_group in [nil, @scope]}
              choices={@choices}
            />
            <Parts.item_tools
              :if={@editing?}
              path="items"
              index={i}
              count={@count}
              spec={@spec}
            />
          </:item>
        </.detail_list>
      </.width>
    </section>
    """
  end

  slot :item, required: true do
    attr :title, :any, required: true, doc: "the detail's label, a string or the editor's words"
    attr :class, :any, doc: "more classes for the item, such as the page editor's"
  end

  # The details as rows between hairlines, with caps labels, drawn from
  # the theme alone, since a site's own list component isn't billboard's
  # to use.
  defp detail_list(assigns) do
    ~H"""
    <dl>
      <div :for={item <- @item} class={["bb-detail bb-rule-top py-4", item[:class]]}>
        <dt class="bb-item-title bb-type-label text-bb-ink-soft">{item.title}</dt>
        <dd class="bb-type-body mt-2 text-bb-ink">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  attr :index, :integer, required: true
  attr :value, :string, default: nil
  attr :here?, :boolean, required: true
  attr :choices, :map, required: true

  # Which of the site's scopes a detail shows on, or every one, changed
  # in place. It goes to the section's editor, which saves it.
  defp shows_on(assigns) do
    options = assigns.choices.options

    # A value that has gone, or isn't there yet, keeps its name.
    gone =
      if assigns.value && not List.keymember?(options, assigns.value, 1),
        do: [{"#{assigns.value} (#{assigns.choices.gone})", assigns.value}],
        else: []

    assigns =
      assign(assigns,
        id: "section-item-items-#{assigns.index}-group",
        options: [{assigns.choices.every, ""} | options] ++ gone
      )

    ~H"""
    <.form
      for={%{}}
      id={@id}
      phx-change="edit_part"
      phx-target="#section-editor"
      class="bb-edit-shows-on"
      data-editor-ui
    >
      <input type="hidden" name="path" value={"items.#{@index}"} />
      <label for={"#{@id}-select"}>Shows on</label>
      <select
        id={"#{@id}-select"}
        name={"section[content][items][#{@index}][only_for_group]"}
      >
        {Phoenix.HTML.Form.options_for_select(@options, @value || "")}
      </select>
      <span :if={!@here?}>Not shown on this page</span>
    </.form>
    """
  end

  @doc """
  Whether there's no head and no detail for this page, so `render/1`
  draws nothing.
  """
  def empty?(content, _data, ctx), do: is_nil(content.head) and shown(content, ctx) == []

  @doc "What the editor's stand-in says when `render/1` draws nothing."
  def nothing_to_show(_content, _ctx), do: "none of its details show on this page."

  # The details this page shows, each with its place among them all:
  # every one, in the open section.
  defp shown(content, ctx) do
    scope = page_scope(ctx)
    items = Enum.with_index(content.items)

    if Words.editing?(ctx),
      do: items,
      else: Enum.filter(items, fn {item, _i} -> item.only_for_group in [nil, scope] end)
  end

  defp page_scope(ctx), do: get_in(ctx, [:context, :scope])

  attr :narrow, :boolean, required: true
  slot :inner_block, required: true

  defp width(%{narrow: true} = assigns),
    do: ~H"""
    <div class="max-w-[35rem]">{render_slot(@inner_block)}</div>
    """

  defp width(assigns), do: ~H"{render_slot(@inner_block)}"

  @doc """
  The details' glyph: rows of a label and its words, between hairlines,
  narrower for a narrow section.
  """
  def glyph(assigns) do
    ~H"""
    <span class={[
      "grid content-center gap-1 px-1",
      if(@content.width == :narrow, do: "w-2/3", else: "flex-1")
    ]}>
      <span :for={_row <- 1..2} class="flex items-center gap-1.5 border-t border-bb-glyph-line pt-1">
        <span class="h-1 w-1/4 bg-bb-glyph-soft"></span>
        <span class="h-1 flex-1 bg-bb-glyph-ink"></span>
      </span>
    </span>
    """
  end
end
