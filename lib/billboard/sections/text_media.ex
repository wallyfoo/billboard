defmodule Billboard.Sections.TextMedia do
  @moduledoc """
  Text and image: a section head, some words, and up to two actions, with
  a 4:3 photograph beside them on wider screens, on the right
  (`:media_right`) or the left (`:media_left`). Text never sits on the
  photograph. `:text_only` has none.

  In the open section, the actions are the editor's to change, and to add
  to, and the photograph has its tools over it (`Parts.editable_photo/1`).
  """
  use Billboard.Renderer

  @doc "Draws the text and image."
  def render(assigns) do
    content = assigns.content

    assigns =
      assign(assigns,
        media:
          cond do
            content.variant == :text_only or is_nil(content.photo) -> nil
            content.variant == :media_left -> "left"
            true -> "right"
          end
      )

    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <%= if @media do %>
        <div
          data-media={@media}
          class={[
            "grid items-start gap-12 md:gap-18",
            if(@media == "left",
              do: "md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]",
              else: "md:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]"
            )
          ]}
        >
          <div><.words content={@content} ctx={@ctx} anchor={@anchor} /></div>
          <div class={if(@media == "left", do: "md:order-first")}>
            <Parts.editable_photo ctx={@ctx} photo={@content.photo}>
              <Blocks.photo
                src={@content.photo.path}
                alt={@content.photo.alt || ""}
                label={@content.photo.label}
                ratio="aspect-[4/3]"
              />
            </Parts.editable_photo>
          </div>
        </div>
      <% else %>
        <.words content={@content} ctx={@ctx} anchor={@anchor} />
      <% end %>
    </section>
    """
  end

  attr :content, :map, required: true
  attr :ctx, :map, required: true
  attr :anchor, :string, required: true

  defp words(assigns) do
    # Narrowing reads the site's options, which only the editor needs.
    max =
      if Words.editing?(assigns.ctx),
        do: EditorFields.narrowed(:text_media)[:actions][:max]

    assigns = assign(assigns, max: max)

    ~H"""
    <Parts.head head={@content.head} ctx={@ctx} prefix={@anchor} />
    <p :if={@content.body || Words.editing?(@ctx)} class="bb-type-body bb-measure text-bb-ink">
      {Words.text(@ctx, "body", @content.body, placeholder: "Some words")}
    </p>
    <Parts.action_group
      :if={@content.actions != [] or Words.editing?(@ctx)}
      actions={@content.actions}
      ctx={@ctx}
      prefix={@anchor}
      class="mt-12"
      max={@max}
    />
    """
  end

  @doc """
  The glyph for text and image: lines of words beside a photograph,
  on the side its variant says, or alone.
  """
  def glyph(assigns) do
    ~H"""
    <span class="flex flex-1 gap-1.5 p-0.5">
      <Glyph.photo :if={@content.variant == :media_left} class="w-2/5" />
      <Glyph.bars rows={3} class="flex-1" />
      <Glyph.photo :if={@content.variant == :media_right} class="w-2/5" />
    </span>
    """
  end
end
