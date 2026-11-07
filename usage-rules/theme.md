# Billboard's theme

Set token values in `assets/css/billboard-tokens.css`. Read them
through the utilities below. `guides/theming.md` has every detail.

## Tokens

A fallback is written where a token is read, never declared on
`:root`. "None" means the tokens file must set it.

Ink:
- `--bb-ink` (none), `--bb-ink-soft` (ink), `--bb-heading` (ink),
  `--bb-title` (heading, ink), `--bb-subheading` (heading, ink),
  `--bb-eyebrow` (accent), `--bb-link` (ink), `--bb-link-hover` (link,
  ink), `--bb-accent` (none)

Lines and fills:
- `--bb-rule` (none), `--bb-rule-width` (1px), `--bb-card` (none),
  `--bb-edge` (rule), `--bb-placeholder` (none), `--bb-placeholder-ink`
  (ink), `--bb-placeholder-chip` (card), `--bb-focus` (ink)
- The tokens file also sets `--bb-rule-gap`, `--bb-card-pad`, and
  `--bb-noise-1` to `--bb-noise-9`, which stock sections read.

Actions:
- `--bb-action` (none), `--bb-on-action` (none), `--bb-action-hover`
  (action), `--bb-on-action-hover` (on-action), `--bb-action-active`
  (action-hover, action), `--bb-on-action-active` (on-action-hover,
  on-action), `--bb-action-2` (none: the secondary button's words),
  `--bb-on-action-2` (none), `--bb-edge-2` (action-2: its outline),
  `--bb-action-2-hover` (action-2: its hover fill), and
  `--bb-on-action-2-hover` (on-action-2: its hover words)

Shape:
- `--bb-radius-card`, `--bb-radius-button`, `--bb-radius-photo`, and
  `--bb-radius-field`, each 0

Faces:
- `--bb-font-body` (none), `--bb-font-heading` (body),
  `--bb-font-display` (heading, body), `--bb-font-label` (body)

Type roles, each a utility; `-size` has no fallback, `-size-md` falls
back to `-size`, `-tracking` to `normal`, and `-case` to `none`:
- `bb-type-display`: `--bb-display-size`, `--bb-display-size-md`, `--bb-display-leading` (1.1), `--bb-display-weight` (400), `--bb-display-tracking`, `--bb-display-case`
- `bb-type-title`: `--bb-title-size`, `--bb-title-size-md`, `--bb-title-leading` (1.15), `--bb-title-weight` (400), `--bb-title-tracking`, `--bb-title-case`
- `bb-type-heading`: `--bb-heading-size`, `--bb-heading-size-md`, `--bb-heading-leading` (1.2), `--bb-heading-weight` (400), `--bb-heading-tracking`, `--bb-heading-case`
- `bb-type-subheading`: `--bb-subheading-size`, `--bb-subheading-size-md`, `--bb-subheading-leading` (1.3), `--bb-subheading-weight` (400), `--bb-subheading-tracking`, `--bb-subheading-case`
- `bb-type-lead`: `--bb-lead-size`, `--bb-lead-size-md`, `--bb-lead-leading` (1.5), `--bb-lead-weight` (400), `--bb-lead-tracking`, `--bb-lead-case`
- `bb-type-body`: `--bb-body-size`, `--bb-body-size-md`, `--bb-body-leading` (1.6), `--bb-body-weight` (400), `--bb-body-tracking`, `--bb-body-case`
- `bb-type-small`: `--bb-small-size`, `--bb-small-size-md`, `--bb-small-leading` (1.5), `--bb-small-weight` (400), `--bb-small-tracking`, `--bb-small-case`
- `bb-type-label`: `--bb-label-size`, `--bb-label-size-md`, `--bb-label-leading` (1.2), `--bb-label-weight` (600), `--bb-label-tracking`, `--bb-label-case`
- `bb-type-eyebrow`: `--bb-eyebrow-size`, `--bb-eyebrow-size-md`, `--bb-eyebrow-leading` (1.2), `--bb-eyebrow-weight` (600), `--bb-eyebrow-tracking`, `--bb-eyebrow-case`
- `bb-type-button`: `--bb-button-size`, `--bb-button-size-md`, `--bb-button-leading` (1), `--bb-button-weight` (600), `--bb-button-tracking`, `--bb-button-case`
- `bb-type-quote`: `--bb-quote-size`, `--bb-quote-size-md`, `--bb-quote-leading` (1.3), `--bb-quote-weight` (400), `--bb-quote-tracking`, `--bb-quote-case`

Space and motion:
- `--bb-content-max` (none), `--bb-gutter` (none), `--bb-gutter-md`
  (gutter), `--bb-section-pad` (none), `--bb-section-pad-md`
  (section-pad), `--bb-measure` (65ch), `--bb-measure-title` (measure,
  24ch), `--bb-ease` (ease), `--bb-duration` (150ms)

## Utilities

- Colours: every colour token is a Tailwind colour without its dashes:
  `text-bb-ink`, `text-bb-heading`, `bg-bb-card`, `border-bb-edge`,
  `bg-bb-action`, and the rest.
- Corners: `rounded-bb-card`, `rounded-bb-button`, `rounded-bb-photo`,
  and `rounded-bb-field`.
- Type: `bb-type-display`, `bb-type-title`, `bb-type-heading`,
  `bb-type-subheading`, `bb-type-lead`, `bb-type-body`, `bb-type-small`,
  `bb-type-label`, `bb-type-eyebrow`, `bb-type-button`, and
  `bb-type-quote`.
- Motion: `ease-bb` and `duration-bb`.
- Layout: `bb-wrap` (the content's width, inside the gutter),
  `bb-section-pad`, `bb-measure`, and `bb-measure-title`.
- `bb-card`: a card's fill, edge, and corners.
- `bb-rule-top`: the hairline above a head, a point, or a detail. Set
  `--bb-rule-width` to 0 to draw none.

## Surfaces

- `bb-surface-NAME` sets only `background-color`, `color`, and custom
  properties. The page's own surface redeclares every token the others
  change.
- List them in `use Billboard.Site`'s `surfaces:`; the first is the
  page's own.
- Tailwind can't see a surface's name in the database: safelist them,
  as `@source inline("bb-surface-{paper,band}");`.

## Hooks

Eleven classes with no styles, for a site's CSS to decorate stock
sections: `bb-title`, `bb-eyebrow`, `bb-heading`, `bb-section-head`,
`bb-point`, `bb-detail`, `bb-item-title`, `bb-quote`, `bb-photo`,
`bb-button`, and `bb-link`.

- Write hook CSS unlayered, outside every `@layer`, or the utilities
  on the same element beat it.
- Make a decorating pseudo-element a block or a flex item, never
  inline.

## Where each class goes

- A stock renderer uses only billboard's utilities and hooks.
- A site's own renderer may use any class, but prefer the tokens' so
  it reads right on every surface.

## The editor

- Its chrome is the `--bb-edit-*` tokens, set on `:root` and read only
  by rules scoped under `.bb-editor`.
- A site changes `--bb-edit-accent` only, after importing `editor.css`.

## Tailwind

- `app.css` gets billboard's five `@source` lines from the installer:
  `sections`, `sections.ex`, `editor_live.ex`, `editor_live`, and
  `editor`, under `vendor/billboard/lib/billboard/`. Never point
  `@source` at billboard's whole `lib`.
