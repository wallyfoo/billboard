defmodule Billboard.Sections.News do
  @moduledoc """
  What's on: the latest posts (`#news-<id>`), two to a row, or the
  section's `empty` words when there are none, or nothing at all when it
  has no words for that. Its bottom padding is deeper than other
  sections', since it's often a page's last, above the footer; in a
  column it has none of its own.

  The posts are the site's, given by section key in the page's data
  (`ctx.data[key]`), which fetches as many as the section's `limit`, in
  the order they're drawn. Each is a map of `id`, `published_on` (a
  `Date`), `title` (plain text), and `body` (Markdown).
  """
  use Billboard.Renderer

  @doc "Draws what's on."
  def render(assigns) do
    assigns = assign(assigns, :news, assigns.ctx.data[assigns.section.key] || [])

    ~H"""
    <section
      :if={!empty?(@content, @news, @ctx)}
      id={@anchor}
      data-surface={@ctx.surface}
      class={Parts.section_class(@ctx) ++ [!@ctx[:in_column] && "pb-18 md:pb-28"]}
    >
      <Parts.head head={@content.head} ctx={@ctx} prefix={@anchor} />
      <Parts.empty_state :if={@news == []} text={@content.empty} class="bb-measure" />
      <div :if={@news != []} class="grid items-start gap-8 md:grid-cols-2">
        <Parts.news_item :for={post <- @news} post={post} />
      </div>
    </section>
    """
  end

  @doc """
  Whether there's no news and no words for when there's none, so
  `render/1` draws nothing.
  """
  def empty?(content, news, _ctx), do: (news || []) == [] and !content.empty

  @doc """
  The glyph for what's on: rows, each with an accent date.
  """
  def glyph(assigns) do
    ~H"""
    <span class="grid flex-1 content-center gap-1.5 px-1">
      <span :for={row <- 1..2} class="flex items-center gap-1.5">
        <span class="size-2 bg-bb-glyph-accent"></span>
        <span class={["h-1 bg-bb-glyph-ink", if(row == 1, do: "w-4/5", else: "w-3/5")]}></span>
      </span>
    </span>
    """
  end
end
