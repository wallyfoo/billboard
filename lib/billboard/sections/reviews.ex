defmodule Billboard.Sections.Reviews do
  @moduledoc """
  The published reviews, drawn by `Blocks.review_block/1`: one at
  display size, or a grid, showing `initial` at first and the rest in
  place. The section's anchor names each review (`#<anchor>-<id>`) and
  the Show all button (`#<anchor>-show-all`), which reveals the rest in
  the browser, with no round trip. With no reviews, it draws nothing at
  all.

  The reviews are the site's, read by its `Billboard.Data` module and
  given by section key in the page's data (`ctx.data[key]`) by
  `Billboard.Resolver`, in the order they're drawn. Each is a map of `id`,
  `name`, `reviewed_on` (a `Date`, drawn as its month and year), and
  `quote`, all plain text but the date.
  """
  use Billboard.Renderer

  @doc "Draws the reviews."
  def render(assigns) do
    %{content: content, ctx: ctx} = assigns

    assigns =
      assign(assigns,
        reviews: ctx.data[assigns.section.key] || [],
        note:
          if(content.note || Words.editing?(ctx),
            do: Words.text(ctx, "note", content.note, placeholder: "Note (optional)")
          )
      )

    ~H"""
    <Blocks.review_block
      :if={!empty?(@content, @reviews, @ctx)}
      id={@anchor}
      data-surface={@ctx.surface}
      class={Parts.section_class(@ctx)}
      reviews={@reviews}
      initial={@content.initial}
    >
      <:head>
        <Parts.head head={@content.head} ctx={@ctx} prefix={@anchor} />
      </:head>
      <:note :if={@note}>{@note}</:note>
    </Blocks.review_block>
    """
  end

  @doc "Whether there are no reviews, so `render/1` draws nothing."
  def empty?(_content, reviews, _ctx), do: (reviews || []) == []

  @doc """
  The reviews' glyph: two quote blocks.
  """
  def glyph(assigns) do
    ~H"""
    <span class="grid flex-1 grid-cols-2 gap-1.5 p-0.5">
      <span :for={_review <- 1..2} class="flex gap-1 border border-bb-glyph-line px-1">
        <Glyph.quote_mark />
        <Glyph.bars class="flex-1" />
      </span>
    </span>
    """
  end
end
