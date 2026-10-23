defmodule Billboard.Sections.Band do
  @moduledoc """
  A band: one idea on a stand-out surface, drawn by `Blocks.band/1`. A
  `:heading` band leads with its heading; a quote band leads with its
  quote, on the left (`:quote_left`) or the right (`:quote_right`). Its
  one action takes the band's anchor as its id prefix.

  A quote's name and the line about them are plain text, not Markdown.
  In the open section, the band's optional words are drawn even when
  empty, to be typed into, and its action is the editor's to change, or
  to add.
  """
  use Billboard.Renderer

  def render(assigns) do
    %{content: band, ctx: ctx} = assigns
    editing? = Words.editing?(ctx)

    assigns =
      assign(assigns,
        eyebrow:
          if(band.eyebrow || editing?,
            do: Words.text(ctx, "eyebrow", band.eyebrow, placeholder: "Eyebrow (optional)")
          ),
        heading:
          if(band.variant == :heading && (band.heading || editing?),
            do: Words.text(ctx, "heading", band.heading)
          ),
        quote: if(band.variant != :heading, do: band.quote),
        quote_side: if(band.variant == :quote_right, do: "right", else: "left"),
        body:
          if(band.body || editing?,
            do: Words.text(ctx, "body", band.body, placeholder: "Words (optional)")
          )
      )

    # A band takes `page-section` alone, not `Parts.section_class/1`:
    # `Blocks.band/1` draws its surface and its padding, with the page
    # margin inside them, and a stand-out section is never joined
    # (by the page), so it has no `bb-joined` to carry.
    ~H"""
    <Blocks.band
      id={@anchor}
      surface={@ctx.surface}
      class="page-section"
      eyebrow={@eyebrow}
      heading={@heading}
      body={@body}
      quote_side={@quote_side}
    >
      <:quote
        :if={@quote}
        name={
          Words.text(@ctx, "quote.name", @quote.name,
            markdown: false,
            placeholder: "Who said it (optional)"
          )
        }
        meta={
          Words.text(@ctx, "quote.meta", @quote.meta,
            markdown: false,
            placeholder: "About them (optional)"
          )
        }
      >
        {Words.text(@ctx, "quote.body", @quote.body)}
      </:quote>
      <:action :if={@content.action || Words.editing?(@ctx)}>
        <Parts.editable_action :if={@content.action} ctx={@ctx} path="action">
          <Parts.action action={@content.action} ctx={@ctx} prefix={@anchor} />
        </Parts.editable_action>
        <Parts.add_button :if={!@content.action} path="action" />
      </:action>
    </Blocks.band>
    """
  end

  @doc """
  The band's glyph: a full dark bar, with a quote mark on the
  quote's side for a quote band.
  """
  def glyph(assigns) do
    ~H"""
    <span class="flex flex-1 items-center gap-1.5 bg-bb-glyph-ink px-2">
      <Glyph.quote_mark :if={@content.variant == :quote_left} class="text-bb-glyph-accent-on-ink" />
      <Glyph.bars
        on_dark
        class={["flex-1", @content.variant == :heading && "justify-items-center"]}
      />
      <Glyph.quote_mark
        :if={@content.variant == :quote_right}
        side="right"
        class="text-bb-glyph-accent-on-ink"
      />
    </span>
    """
  end
end
