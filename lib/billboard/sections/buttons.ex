defmodule Billboard.Sections.Buttons do
  @moduledoc """
  The buttons and links stock sections draw, from billboard's tokens. A
  surface sets the tokens, so the same button is right on any ground.

  A button carries the `bb-button` hook and a link the `bb-link` hook, so
  a site can decorate them without replacing them. Their geometry reads
  tokens that fall back to 2.75rem, 1.5rem, and 1px: `--bb-button-height`,
  `--bb-button-pad-x`, and `--bb-button-border` for a button, and
  `--bb-link-decoration` and `--bb-link-offset` for a link.

  So `class` no longer changes that geometry. The tokens are drawn
  through arbitrary values, which Tailwind sorts after its named
  utilities, so a caller's `px-8`, `min-h-14`, `border-0`, or
  `underline-offset-2` loses. Change it through the tokens, which work
  for one element too, as in `class="[--bb-button-pad-x:2rem]"`. A
  caller's `no-underline` still wins, since Tailwind sorts it after an
  arbitrary property, but `--bb-link-decoration: none` says the same.

  `bb_button/1` has no disabled styles, and takes no form attributes
  (`disabled`, `name`, `value`, `form`, or `download`), since stock
  sections draw only links and enabled buttons.
  """
  use Phoenix.Component

  @doc """
  A button, or a link drawn as one when `href`, `navigate`, or `patch` is
  given. `primary` fills with the action colour, and `secondary` is
  outlined in the second action colour and fills with it on hover.
  """
  attr :rest, :global, include: ~w(href navigate patch method target rel type)
  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary secondary), default: "primary"
  slot :inner_block, required: true

  def bb_button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :classes, [
        "bb-button bb-type-button inline-flex items-center justify-center gap-2 rounded-bb-button",
        # Its height, side padding, and border width are tokens, each
        # falling back to 44px, 24px, and 1px. The
        # border's `length:` hint tells Tailwind the token is a width, not
        # a colour.
        "min-h-[var(--bb-button-height,2.75rem)] px-[var(--bb-button-pad-x,1.5rem)]",
        "border-[length:var(--bb-button-border,1px)]",
        "cursor-pointer transition-colors duration-bb ease-bb",
        "phx-submit-loading:opacity-75",
        skin(assigns.variant),
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>
        <span class="inline-block">{render_slot(@inner_block)}</span>
      </.link>
      """
    else
      ~H"""
      <button class={@classes} {@rest}>
        <span class="inline-block">{render_slot(@inner_block)}</span>
      </button>
      """
    end
  end

  defp skin("primary"),
    do:
      "border-bb-action bg-bb-action text-bb-on-action hover:border-bb-action-hover hover:bg-bb-action-hover hover:text-bb-on-action-hover active:border-bb-action-active active:bg-bb-action-active active:text-bb-on-action-active"

  defp skin("secondary"),
    do:
      "border-bb-action-2 bg-transparent text-bb-action-2 hover:bg-bb-action-2 hover:text-bb-on-action-2"

  @doc """
  A text link with a 1px underline that clears on hover. Tones: `ink` for
  ordinary links, `accent` for the page's main action, and `quiet` for
  tertiary ones. An `ink` link also
  takes the link-hover colour on hover, which falls back to the link's.
  """
  attr :tone, :string, values: ~w(ink accent quiet), default: "ink"
  attr :compact, :boolean, default: false, doc: "drop the 44px tap height inside dense rows"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method target rel)
  slot :inner_block, required: true

  # Its line and offset are tokens, falling back to an underline 4px
  # below the text. Hover clears the line's colour, not the line, so it
  # clears whichever line a site sets.
  def bb_link(assigns) do
    ~H"""
    <.link
      class={[
        "bb-link bb-type-label inline-flex items-center decoration-1",
        "[text-decoration-line:var(--bb-link-decoration,underline)]",
        "underline-offset-[var(--bb-link-offset,4px)]",
        "transition-[color,text-decoration-color] duration-bb ease-bb",
        "hover:decoration-transparent",
        !@compact && "min-h-11",
        tone(@tone),
        @class
      ]}
      {@rest}
    >
      <span class="inline-block">{render_slot(@inner_block)}</span>
    </.link>
    """
  end

  defp tone("ink"), do: "text-bb-link hover:text-bb-link-hover"
  defp tone("accent"), do: "text-bb-accent"
  defp tone("quiet"), do: "text-bb-ink-soft"
end
