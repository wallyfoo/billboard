defmodule Billboard.Sections.Prices do
  @moduledoc """
  A price list: rows between hairlines, each with its title on the
  left, and its price, with its unit under it, on the right. With
  opening words, and always in the open section, the head, the words,
  and the action sit on one side and the rows beside them, from `md`
  up, and above them on narrower screens and in a column; with none,
  the head sits above the rows. The section's note follows the rows.
  The section's anchor names each row (`#<anchor>-<id>`), which
  carries the `bb-price` hook.

  The rows are the site's, read by its `Billboard.Data` module and
  given by section key in the page's data (`ctx.data[key]`) by
  `Billboard.Resolver`, in the order they're drawn. Each is a map of:

    * `id`, which names the row's element;
    * `title`, what it's for;
    * `price`, a string the site has already formatted, as `"£1,950"`,
      `"from £40"`, or `"Free"`, drawn as it is;
    * `unit`, optional, what the price is for, as `"60 minutes"` or
      `"total"`, drawn under the price;
    * `note`, optional, drawn under the title;
    * `group`, optional, a string matching one of the values of the
      site's `:scope` choices (`Billboard.Context`), which says whose
      price it is.

  All are plain text. The section shows the rows of its `group`, when
  one is chosen, wherever it is; otherwise, with `this_page_only` on,
  those whose `group` is the page's scope (`ctx.context.scope`), and
  none on a page about nothing; otherwise every row. With none to show,
  it draws nothing at all, and the editor's stand-in says why.
  """
  use Billboard.Renderer

  @doc "Draws the price list."
  def render(assigns) do
    %{content: content, ctx: ctx} = assigns
    editing? = Words.editing?(ctx)

    assigns =
      assign(assigns,
        rows: shown(content, ctx.data[assigns.section.key], ctx),
        beside?: !!content.body or editing?,
        editing?: editing?,
        note:
          if(content.note || editing?,
            do: Words.text(ctx, "note", content.note, placeholder: "Note (optional)")
          ),
        # Narrowing reads the site's options, which only the editor needs.
        max: if(editing?, do: EditorFields.narrowed(:prices)[:actions][:max])
      )

    ~H"""
    <section
      :if={@rows != []}
      id={@anchor}
      data-surface={@ctx.surface}
      class={Parts.section_class(@ctx)}
    >
      <%= if @beside? do %>
        <div class={[
          "grid items-start gap-x-18 gap-y-8",
          !@ctx[:in_column] && "md:grid-cols-[minmax(0,5fr)_minmax(0,6fr)]"
        ]}>
          <div>
            <Parts.head head={@content.head} ctx={@ctx} prefix={@anchor} />
            <div class="bb-type-body bb-measure text-bb-ink">
              {Words.text(@ctx, "body", @content.body, placeholder: "Opening words")}
            </div>
            <Parts.action_group
              :if={@content.actions != [] or @editing?}
              actions={@content.actions}
              ctx={@ctx}
              prefix={@anchor}
              class="mt-8"
              max={@max}
            />
          </div>
          <.rows rows={@rows} anchor={@anchor} note={@note} />
        </div>
      <% else %>
        <Parts.head head={@content.head} ctx={@ctx} prefix={@anchor} />
        <.rows rows={@rows} anchor={@anchor} note={@note} />
      <% end %>
    </section>
    """
  end

  attr :rows, :list, required: true
  attr :anchor, :string, required: true
  attr :note, :any, default: nil, doc: "the section's note, a string or the editor's words"

  defp rows(assigns) do
    ~H"""
    <div class="bb-measure">
      <ul>
        <li
          :for={row <- @rows}
          id={"#{@anchor}-#{row.id}"}
          class="bb-price bb-rule-top flex items-baseline justify-between gap-6 py-4"
        >
          <span class="min-w-0">
            <span class="bb-type-body block text-bb-ink">{row.title}</span>
            <span :if={Map.get(row, :note)} class="bb-type-small block text-bb-ink-soft">
              {Map.get(row, :note)}
            </span>
          </span>
          <span class="shrink-0 text-right">
            <span class="bb-type-subheading block text-bb-subheading">{row.price}</span>
            <span :if={Map.get(row, :unit)} class="bb-type-small block text-bb-ink-soft">
              {Map.get(row, :unit)}
            </span>
          </span>
        </li>
      </ul>
      <div :if={@note} class="bb-type-small mt-4 text-bb-ink-soft">{@note}</div>
    </div>
    """
  end

  @doc "Whether no row is shown here, so `render/1` draws nothing."
  def empty?(content, rows, ctx), do: shown(content, rows, ctx) == []

  @doc "What the editor's stand-in says when `render/1` draws nothing."
  def nothing_to_show(%{group: group}, _ctx) when is_binary(group),
    do: "there are no prices in its group."

  def nothing_to_show(%{this_page_only: true}, ctx) do
    if get_in(ctx, [:context, :scope]),
      do: "there are no prices for this page.",
      else: "it shows only this page's prices, and this page is about nothing in particular."
  end

  def nothing_to_show(_content, _ctx), do: "there are no prices."

  # A group chosen here wins, wherever the section is; then, with
  # `this_page_only`, the page's scope, which a page about nothing hasn't
  # got; then every row.
  defp shown(%{group: group}, rows, _ctx) when is_binary(group), do: only(rows, group)
  defp shown(%{this_page_only: true}, rows, ctx), do: only(rows, page_scope(ctx))
  defp shown(_content, rows, _ctx), do: rows || []

  defp only(_rows, nil), do: []
  defp only(rows, group), do: Enum.filter(rows || [], &(Map.get(&1, :group) == group))

  defp page_scope(ctx), do: get_in(ctx, [:context, :scope])

  @doc """
  The prices' glyph: a heading over rows between hairlines, each a
  title and its price.
  """
  def glyph(assigns) do
    ~H"""
    <span class="grid flex-1 content-center gap-1 px-1">
      <span class="h-1.5 w-1/3 bg-bb-glyph-ink"></span>
      <span :for={_row <- 1..2} class="flex justify-between border-t border-bb-glyph-line pt-1">
        <span class="h-1 w-1/2 bg-bb-glyph-soft"></span>
        <span class="h-1 w-1/6 bg-bb-glyph-accent"></span>
      </span>
    </span>
    """
  end
end
