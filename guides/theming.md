# Theming

This guide makes billboard's pages look like the site's. It covers the
tokens file the installer writes, every token billboard reads, the
surfaces a section is drawn on, the dark theme, the utilities and hooks
the theme gives, buttons and links, what the theme check holds stock
code to, and the editor's own look. At the end you'll know which value
to change for any look the stock sections draw, and how to decorate
them without replacing them.

## Tokens name roles, not colours

Billboard's stock sections never name a colour, a face, or a size.
They draw through tokens, plain CSS custom properties named for what
they're for: `--bb-ink` for body copy, `--bb-heading` for section
headings, `--bb-action` for the primary button. The site gives each
token its value, so one renderer reads right on every site, and on
every surface of a site, since a surface changes the tokens for
everything inside it.

Most tokens fall back to another, so a site sets only what differs:
`--bb-heading` falls back to `--bb-ink`, and a site whose headings are
the colour of its words never sets it. A fallback is written where the
token is read, as in `var(--bb-heading, var(--bb-ink))`, never as a
declaration on `:root`. A custom property that names another is fixed
where it's declared: `--bb-heading: var(--bb-ink)` on `:root` would
take `:root`'s ink, and keep it on a dark band that sets an ink of its
own, where the heading would vanish.

## Your tokens file

`mix billboard.install` writes `assets/css/billboard-tokens.css`, which
`app.css` imports before billboard's theme. It sets every token that
has no fallback, and names the rest in comments, with what each falls
back to: take one out of its comment to set it. A token set to
`initial` takes its fallback too, since `var()` treats `initial` as
unset.

Its first block is paper, the page's own surface:

<!-- from: priv/templates/billboard.install/billboard-tokens.css#paper -->
```css
:root,
.bb-surface-paper {
  /* Ink, on whatever ground a section sits on. */
  --bb-ink: #1c1c1c;               /* body copy */
  --bb-ink-soft: #5b5b5b;          /* captions and meta; falls back to --bb-ink */
  --bb-heading: initial;           /* section headings; falls back to --bb-ink */
  --bb-accent: #1c1c1c;            /* short rules and marks, and the eyebrow's fallback */
  --bb-link: initial;              /* text links; falls back to --bb-ink */
  /* --bb-title: the page headline; falls back to --bb-heading, then --bb-ink */
  /* --bb-subheading: item and card titles; falls back to --bb-heading, then --bb-ink */
  /* --bb-eyebrow: falls back to --bb-accent */
  /* --bb-link-hover: falls back to --bb-link, then --bb-ink */

  /* Lines and fills. */
  --bb-rule: #d9d9d9;              /* hairlines between related things */
  --bb-focus: #1c1c1c;             /* the keyboard focus ring; falls back to --bb-ink */
  --bb-card: #ffffff;              /* a card's fill */
  --bb-edge: initial;              /* a card's boundary; falls back to --bb-rule */

  /* Actions. */
  --bb-action: #1c1c1c;            /* the primary button */
  --bb-on-action: #ffffff;         /* its ink */
  --bb-action-hover: #3a3a3a;      /* falls back to --bb-action */
  --bb-action-active: initial;     /* falls back to --bb-action-hover */
  --bb-on-action-active: initial;  /* falls back to --bb-on-action-hover */
  --bb-action-2: #1c1c1c;          /* the secondary button's words, and its outline and hover fill unless set */
  --bb-on-action-2: #ffffff;       /* its words when it fills on hover */
  /* --bb-on-action-hover: falls back to --bb-on-action */
  --bb-edge-2: initial;            /* the secondary button's outline; falls back to --bb-action-2 */
  --bb-action-2-hover: initial;    /* its fill on hover; falls back to --bb-action-2 */
  --bb-on-action-2-hover: initial; /* its words on hover; falls back to --bb-on-action-2 */
}
```

Paper sets its tokens on `:root` and on `.bb-surface-paper` together,
so paper inside another surface puts them back
([Surfaces](#surfaces)). The tokens no surface changes, such as the
type, the space, and the shape, are set on `:root` alone, in the
second block, since custom properties inherit.

At its end are the surfaces themselves, the safelist, paper's utility,
and the band's:

<!-- from: priv/templates/billboard.install/billboard-tokens.css#surfaces -->
```css
/* Sections name their surface in their data, so no source file names
   these classes for Tailwind to find. This keeps both in the build. */
@source inline("bb-surface-{paper,band}");

/* The page's own surface. The body paints the page, so paper paints no
   ground of its own, except inside another surface that sets
   --paper-ground, as the band does. */
@utility bb-surface-paper {
  background-color: var(--paper-ground, transparent);
  color: var(--bb-ink);
}

/* The stand-out band: the hero, and any Band section. Its ground is
   --band-ground, near-black unless the site sets it, as it may on :root
   and in each theme. It redefines the ink, line, focus, and action
   tokens for everything inside it. */
@utility bb-surface-band {
  background-color: var(--band-ground, #1c1c1c);
  color: #ffffff;
  --bb-ink: #e8e8e8;
  --bb-ink-soft: #b8b8b8;
  --bb-heading: #ffffff;
  --bb-accent: #ffffff;
  --bb-link: #ffffff;
  --bb-rule: rgb(255 255 255 / 0.25);
  --bb-focus: #ffffff;
  --bb-card: #2a2a2a;
  --bb-edge: rgb(255 255 255 / 0.25);
  --bb-action: #ffffff;
  --bb-on-action: #1c1c1c;
  --bb-action-hover: #d9d9d9;
  --bb-action-active: initial;
  --bb-on-action-active: initial;
  --bb-action-2: #ffffff;
  --bb-on-action-2: #1c1c1c;
  --bb-edge-2: initial;
  --bb-action-2-hover: initial;
  --bb-on-action-2-hover: initial;
  --paper-ground: #ffffff;
}
```

## Every token

Each token below is in the group the tokens file has it in. "None"
means it has no fallback: the tokens file sets it, and a site must
keep it set.

### Ink

| Token | What it's for | Falls back to |
| --- | --- | --- |
| `--bb-ink` | body copy, and what most of the others fall back to | none |
| `--bb-ink-soft` | captions and meta, such as a detail's label | `--bb-ink` |
| `--bb-title` | the page's headline, the hero's heading | `--bb-heading`, then `--bb-ink` |
| `--bb-heading` | section headings | `--bb-ink` |
| `--bb-subheading` | item and card titles, and a quote's name | `--bb-heading`, then `--bb-ink` |
| `--bb-eyebrow` | eyebrows | `--bb-accent` |
| `--bb-link` | text links | `--bb-ink` |
| `--bb-link-hover` | a text link under the pointer | `--bb-link`, then `--bb-ink` |
| `--bb-accent` | short rules and marks, a link in the accent tone, and the eyebrow's fallback | none |

### Lines and fills

| Token | What it's for | Falls back to |
| --- | --- | --- |
| `--bb-rule` | hairlines between related things | none |
| `--bb-rule-width` | the hairline above a head, a point, and a detail; 0 draws none | 1px |
| `--bb-rule-gap` | the room between that hairline and the head or point below it | 1.5rem |
| `--bb-card` | a card's fill | none |
| `--bb-edge` | a card's boundary | `--bb-rule` |
| `--bb-card-pad` | the room inside a card in Points' cards look | 1.5rem |
| `--bb-placeholder` | the photograph stand-in's ground | none |
| `--bb-placeholder-ink` | the stand-in's label | `--bb-ink` |
| `--bb-placeholder-chip` | the label's ground | `--bb-card` |
| `--bb-noise-1` to `--bb-noise-9` | the stand-in's pattern, dark to light in the tokens file | none: set all nine |
| `--bb-focus` | the keyboard focus ring | `--bb-ink` |

#### One place's hairline

`--bb-rule-width` and `--bb-rule-gap` are read on the element that
draws the hairline, and that element carries a hook: a section head's
is `bb-section-head`, a point's `bb-point`, and a detail's `bb-detail`
([Hooks for decoration](#hooks-for-decoration)). Nothing inside a head
draws a hairline of its own. So setting them on a hook changes that
place's hairline alone, and `:root`'s value holds everywhere else. A
site that draws no hairline above its section heads, since the change
of ground parts its sections already, but keeps one between the rows
of Points and Details, sets this in its tokens file or `app.css`:

<!-- from: test/support/guides/theming.css#head-rule -->
```css
.bb-section-head {
  --bb-rule-width: 0;
  --bb-rule-gap: 0;
}
```

`--bb-rule-gap: 0` takes away the room the hairline stood in, too; a
head keeps its eyebrow and heading, and its room below. Unlike hook
CSS that draws, these lines may sit in any `@layer`, or none: they set
custom properties, which no utility on the element sets, so nothing
competes with them. The same works on `.bb-point` or `.bb-detail`, and
inside a surface, as in `.bb-surface-band .bb-section-head`.

The nine noise tokens are `--bb-noise-1`, `--bb-noise-2`,
`--bb-noise-3`, `--bb-noise-4`, `--bb-noise-5`, `--bb-noise-6`,
`--bb-noise-7`, `--bb-noise-8`, and `--bb-noise-9`.

### Actions

| Token | What it's for | Falls back to |
| --- | --- | --- |
| `--bb-action` | the primary button's fill and edge | none |
| `--bb-on-action` | its words | none |
| `--bb-action-hover` | its fill under the pointer | `--bb-action` |
| `--bb-on-action-hover` | its words under the pointer | `--bb-on-action` |
| `--bb-action-active` | its fill as it's pressed | `--bb-action-hover`, then `--bb-action` |
| `--bb-on-action-active` | its words as it's pressed | `--bb-on-action-hover`, then `--bb-on-action` |
| `--bb-action-2` | the secondary button's words | none |
| `--bb-on-action-2` | its words under the pointer, unless `--bb-on-action-2-hover` is set | none |
| `--bb-edge-2` | the secondary button's outline, at rest and under the pointer | `--bb-action-2` |
| `--bb-action-2-hover` | the secondary button's fill under the pointer; at rest it has none | `--bb-action-2` |
| `--bb-on-action-2-hover` | its words under the pointer | `--bb-on-action-2` |
| `--bb-button-height` | a button's least height | 2.75rem |
| `--bb-button-pad-x` | a button's room at each side | 1.5rem |
| `--bb-button-border` | a button's edge | 1px |
| `--bb-link-decoration` | a text link's line, such as `none` | underline |
| `--bb-link-offset` | how far below the words the line sits | 4px |

A site that sets none of `--bb-edge-2`, `--bb-action-2-hover`, and
`--bb-on-action-2-hover` gets the secondary button billboard has always
drawn: outlined in `--bb-action-2`, and filled with it on hover, words
in `--bb-on-action-2`. Set them to part the three, as for a button
with a teal outline, dark words, and a pale fill on hover:

<!-- from: test/support/guides/theming.css#secondary -->
```css
:root,
.bb-surface-paper {
  --bb-action-2: #1c1c1c;
  --bb-on-action-2: #ffffff;
  --bb-edge-2: #2f7f7a;
  --bb-action-2-hover: #e7efee;
  --bb-on-action-2-hover: #1c1c1c;
}
```

The installed tokens file sets all three to `initial` on paper, on the
band, and in both dark blocks, so each takes its fallback everywhere.
Give one a value on paper and the band keeps its `initial`, so a
secondary button on the band is still outlined and filled in the
band's own `--bb-action-2`. A site whose tokens file came from an
earlier billboard has none of the three lines: until it sets one,
nothing changes, and once it sets one on paper, it adds
`--bb-edge-2: initial;` and the rest to every other surface, and to
both dark blocks, or those inherit paper's value.

Hover clears a link's line by its colour, not the line itself, so it
clears whatever line a site sets. A site that sets `--bb-link-decoration`
to `none` gives hover a cue of its own, through `--bb-link-hover` or the
`bb-link` hook.

### Shape

| Token | What it's for | Falls back to |
| --- | --- | --- |
| `--bb-radius-card` | a card's corners | 0 |
| `--bb-radius-button` | a button's corners | 0 |
| `--bb-radius-photo` | a photograph's corners | 0 |
| `--bb-radius-field` | a form field's corners, for the site's own fields; no stock section draws one | 0 |
| `--bb-photo-ratio` | the hero's and Text and image's photograph's width to height, as `1` or `3/2` | `4/3` |
| `--bb-hero-photo-ratio` | the hero's photograph's alone | `--bb-photo-ratio`, then `4/3` |
| `--bb-hero-photo-max` | the hero's photograph's widest, ring and all; narrower than its column, it's centred there | none: the column's width |

A photograph's ratio is its frame's: an uploaded image fills it with a
centre crop, and the stand-in fills it too. `--bb-photo-ratio: 1` makes
them square, and a square with `--bb-radius-photo: 50%` is a circle; a
rounded corner on a 4:3 frame is an ellipse at most. To make the hero's
photograph alone round, set the hero's tokens and the radius on its
hook ([Hooks for decoration](#hooks-for-decoration)).

### Type

Five faces, and eleven roles, each a utility that reads its own set of
tokens.

| Token | What it's for | Falls back to |
| --- | --- | --- |
| `--bb-font-body` | the body face: the lead, body, and small roles | none |
| `--bb-font-heading` | the heading face: the title, heading, and subheading roles, and the quote's unless `--bb-font-quote` is set | `--bb-font-body` |
| `--bb-font-display` | the display face: the display role | `--bb-font-heading`, then `--bb-font-body` |
| `--bb-font-quote` | the quote face: the quote role, which sets a band's pull quote and a review shown alone | `--bb-font-heading`, then `--bb-font-body` |
| `--bb-font-label` | the label face: the label, eyebrow, and button roles | `--bb-font-body` |

A site with one typeface needs only `--bb-font-body`, since the other
four fall back to it. A site that sets its quotes in the body face, not
the heading's, sets `--bb-font-quote: var(--bb-font-body)` on `:root`,
beside its other faces; a site that never sets it sees its quotes as
before, in the heading face.

| Role | Utility | Its tokens, and their fallbacks |
| --- | --- | --- |
| display | `bb-type-display` | `--bb-display-size`, `--bb-display-size-md`, `--bb-display-leading` (1.1), `--bb-display-weight` (400), `--bb-display-tracking`, `--bb-display-case` |
| title | `bb-type-title` | `--bb-title-size`, `--bb-title-size-md`, `--bb-title-leading` (1.15), `--bb-title-weight` (400), `--bb-title-tracking`, `--bb-title-case` |
| heading | `bb-type-heading` | `--bb-heading-size`, `--bb-heading-size-md`, `--bb-heading-leading` (1.2), `--bb-heading-weight` (400), `--bb-heading-tracking`, `--bb-heading-case` |
| subheading | `bb-type-subheading` | `--bb-subheading-size`, `--bb-subheading-size-md`, `--bb-subheading-leading` (1.3), `--bb-subheading-weight` (400), `--bb-subheading-tracking`, `--bb-subheading-case` |
| lead | `bb-type-lead` | `--bb-lead-size`, `--bb-lead-size-md`, `--bb-lead-leading` (1.5), `--bb-lead-weight` (400), `--bb-lead-tracking`, `--bb-lead-case` |
| body | `bb-type-body` | `--bb-body-size`, `--bb-body-size-md`, `--bb-body-leading` (1.6), `--bb-body-weight` (400), `--bb-body-tracking`, `--bb-body-case` |
| small | `bb-type-small` | `--bb-small-size`, `--bb-small-size-md`, `--bb-small-leading` (1.5), `--bb-small-weight` (400), `--bb-small-tracking`, `--bb-small-case` |
| label | `bb-type-label` | `--bb-label-size`, `--bb-label-size-md`, `--bb-label-leading` (1.2), `--bb-label-weight` (600), `--bb-label-tracking`, `--bb-label-case` |
| eyebrow | `bb-type-eyebrow` | `--bb-eyebrow-size`, `--bb-eyebrow-size-md`, `--bb-eyebrow-leading` (1.2), `--bb-eyebrow-weight` (600), `--bb-eyebrow-tracking`, `--bb-eyebrow-case` |
| button | `bb-type-button` | `--bb-button-size`, `--bb-button-size-md`, `--bb-button-leading` (1), `--bb-button-weight` (600), `--bb-button-tracking`, `--bb-button-case` |
| quote | `bb-type-quote` | `--bb-quote-size`, `--bb-quote-size-md`, `--bb-quote-leading` (1.3), `--bb-quote-weight` (400), `--bb-quote-tracking`, `--bb-quote-case` |

A role's `-size` has no fallback, so the tokens file sets each one. Its
`-size-md`, from Tailwind's `md` breakpoint, falls back to its `-size`.
Its `-tracking` falls back to `normal`, and its `-case`, a
`text-transform`, to `none`, as in `--bb-eyebrow-case: uppercase`.
Every role sets `font-style: normal`, so an inherited italic never
reaches it, and none has a `-style` token. The eyebrow is the one role
with a colour of its own, `--bb-eyebrow`, so a surface that changes the
accent changes its eyebrows. A text link is drawn in the label role.

### Space and motion

| Token | What it's for | Falls back to |
| --- | --- | --- |
| `--bb-content-max` | the content's width | none |
| `--bb-gutter` | the page's side margin | none |
| `--bb-gutter-md` | the side margin from the `md` breakpoint | `--bb-gutter` |
| `--bb-section-pad` | the room above and below a section | none |
| `--bb-section-pad-md` | that room from the `md` breakpoint | `--bb-section-pad` |
| `--bb-measure` | the longest line of words | 65ch |
| `--bb-measure-title` | the longest line of a headline | `--bb-measure`, then 24ch |
| `--bb-ease` | the easing of a hover or a press | `ease` |
| `--bb-duration` | how long a hover or a press takes | 150ms |

## Surfaces

A surface is a ground and the ink that reads on it: a utility,
`bb-surface-NAME`, that sets only `background-color`, `color`, and
custom properties. The band, above, redefines the ink, line, focus,
card, and action tokens for everything inside it, so a heading on the
band reads `--bb-heading` as any heading does, and the band has made it
white. A surface sets nothing else, such as an edge, so a card that
sits on a surface of its own takes that surface's ground in place of
its fill.

The site lists its surfaces in `use Billboard.Site`, in order, and the
first is the page's own, paper in the installed site. The page's own
surface paints no ground, since the page's body already does, and a
ground under a section's words would change how the editor fades it.
It must redeclare every token any other surface changes, setting one
it leaves to its fallback to `initial`: that's what makes paper inside
the band read as paper. Paper inside another surface must paint,
though, or the band's ground would show round it, so paper paints
`--paper-ground`, which is transparent unless the surface around it
sets one, as the band does. That's one way to do it; billboard reads
neither `--paper-ground` nor `--band-ground`, which are the tokens
file's own.

The site offers its surfaces by kind, in `offered:`. A section is
`:page`, on the page's ground, or `:stand_out`, breaking from it, as a
Band does, and the site offers each of those at least one surface.
`:card` is a card inside a section, such as one of Points' in its
cards look, and may be offered none, since a card that names no surface
is drawn on its section's. Each kind's first is its default. The
editor shows a Ground setting where a section's kind is offered two or
more, and on each card wherever cards are offered one or more
(`Billboard.Surfaces`).

A section records its surface by name, so no file names
`bb-surface-band` for Tailwind to find: the safelist line,
`@source inline("bb-surface-{paper,band}")`, keeps every surface's
utility in the build, and a site that adds a surface adds it there
too. A surface the site stops offering never locks a section out: it's
drawn on its kind's default until someone chooses again.

A site with seven grounds, three of them for the page and four that
stand out, lists them so:

<!-- sketch -->
```elixir
use Billboard.Site,
  # The site's other answers, and then:
  surfaces: [
    %{name: "paper", label: "Paper"},
    %{name: "sand", label: "Sand"},
    %{name: "sky", label: "Sky"},
    %{name: "night", label: "Night"},
    %{name: "forest", label: "Forest"},
    %{name: "plum", label: "Plum"},
    %{name: "inverse", label: "Inverse"}
  ],
  offered: [
    page: ["paper", "sand", "sky"],
    stand_out: ["night", "forest", "plum", "inverse"],
    card: ["paper", "sand", "sky"]
  ]
```

Its tokens file has a `bb-surface-NAME` utility for each, paper sets
every token any of the six others changes, and its safelist names all
seven: `@source inline("bb-surface-{paper,sand,sky,night,forest,plum,inverse}")`.

## Themes

A site with a light and a dark theme redefines the same surfaces'
tokens under `[data-theme]`, and billboard needs nothing for it: the
sections read the tokens, whatever set them.

The installed tokens file does this for paper already. phx.new's layout
switches between a light and a dark theme, with `data-theme` on
`<html>`, or none to follow the system's, and paints the page dark in
the dark one, so paper's words must be light there:

<!-- from: priv/templates/billboard.install/billboard-tokens.css#dark -->
```css
[data-theme=dark],
[data-theme=dark] .bb-surface-paper {
  --bb-ink: #e6e8eb;
  --bb-ink-soft: #a9b0b8;
  --bb-heading: initial;
  --bb-accent: #f4f5f7;
  --bb-link: initial;
  --bb-rule: rgb(255 255 255 / 0.18);
  --bb-focus: #ffffff;
  --bb-card: #333a44;
  --bb-edge: initial;
  --bb-action: #f4f5f7;
  --bb-on-action: #1c1c1c;
  --bb-action-hover: #d5d9de;
  --bb-action-active: initial;
  --bb-on-action-active: initial;
  --bb-action-2: #f4f5f7;
  --bb-on-action-2: #1c1c1c;
  --bb-edge-2: initial;
  --bb-action-2-hover: initial;
  --bb-on-action-2-hover: initial;
  --bb-placeholder: #343b45;
  --bb-placeholder-ink: #e6e8eb;
  --bb-placeholder-chip: #1e2329;
  /* Paper paints the dark page's ground, so paper inside the band, which
     sets a white one for the light theme, is dark too. */
  --paper-ground: var(--color-base-100, #292f37);
}
```

The same declarations follow, for a page that follows the system,
under `@media (prefers-color-scheme: dark)`, on
`:root:not([data-theme])` and `:root:not([data-theme]) .bb-surface-paper`,
so a page whose theme is chosen light stays light on a dark system. The
two blocks must stay alike, and billboard's tests of the tokens file
check that they are.

- Dark paper sets `--paper-ground` to the page's own ground, so paper
  at the top of the page looks as it did, and paper inside the band,
  which sets a white ground for the light theme, reads dark too.
- The band keeps its near-black, `#1c1c1c`, darker than the dark page,
  so it still stands out. Its ground is `--band-ground`, which the band
  reads with that fallback, so a site that wants another ground in the
  dark theme sets `--band-ground` in both dark blocks, and one that
  wants another everywhere sets it on `:root`.
- A token the site sets in paper must be set in both dark blocks too,
  or it keeps its light value on the dark page. So one taken out of its
  comment in paper, such as `--bb-title`, `--bb-subheading`,
  `--bb-eyebrow`, or `--bb-link-hover`, needs a line in each, as the
  tokens file's comment says.

A site with one theme can delete both blocks.

## The utilities

`theme.css`, which `app.css` imports after the tokens file, turns the
tokens into Tailwind utilities. Each carries the `bb-` prefix, so none
can clash with a name the site has already, such as daisyUI's `card`.

- **Colours:** each colour token is a Tailwind colour, named without
  its dashes and with its fallbacks, as `--bb-ink` is `bb-ink`: so
  `text-bb-ink`, `text-bb-ink-soft`, `text-bb-heading`, `bg-bb-card`,
  `border-bb-edge`, `bg-bb-action`, and the rest.
- **Corners:** `rounded-bb-card`, `rounded-bb-button`,
  `rounded-bb-photo`, and `rounded-bb-field`.
- **Type:** the eleven roles, from `bb-type-display` to
  `bb-type-quote`.
- **Motion:** `ease-bb` and `duration-bb`.
- **Layout:** `bb-wrap`, the content's width, centred, inside the
  gutter; `bb-section-pad`, a section's room above and below;
  `bb-measure`; and `bb-measure-title`.
- **`bb-card`:** a card's fill, edge, and corners, all from tokens. The
  room inside is its user's, as Points' cards look reads
  `--bb-card-pad`.
- **`bb-rule-top`:** the hairline above a head, a point, and a detail,
  from `--bb-rule-width` and `--bb-rule`. Set `--bb-rule-width` to 0,
  not a border class, to draw none: on `:root` for every one, or on a
  hook for one place's ([One place's hairline](#one-place-s-hairline)).

The theme also rings whatever has the keyboard's focus in
`--bb-focus`, a 2px outline 2px out, in Tailwind's base layer, so any
`focus-visible:` utility beats it; and it drops the top padding of a
section that follows another on the same surface (`bb-joined`, which
the page marks), so the two sit one section's padding apart.

A site's own components may use any class, Tailwind's or the site's
own. The stock renderers use only these, so any site's tokens restyle
them.

## Hooks for decoration

Twelve parts of the stock sections carry a class with no styles of its
own, and no stylesheet of billboard's defines it, so a site can
decorate them in its CSS without replacing a component:

| Hook | Where it is |
| --- | --- |
| `bb-title` | the hero's headline |
| `bb-eyebrow` | every eyebrow: the hero's, a section head's, and a band's |
| `bb-heading` | a section head's heading, and a band's |
| `bb-section-head` | a section head's wrapper |
| `bb-point` | each point in Points |
| `bb-detail` | each row in Details |
| `bb-price` | each row in Prices |
| `bb-item-title` | a point's title, a detail's label, and a news post's title |
| `bb-quote` | a quote's words |
| `bb-photo` | a photograph's figure |
| `bb-button` | every button `bb_button/1` draws |
| `bb-link` | every text link `bb_link/1` draws |

A hook can set tokens as well as draw, and what's inside it reads
them. `bb-photo` is the photograph's figure, and the frame inside it,
which no hook names, reads `--bb-radius-photo` and the ratio tokens,
so it takes whatever the figure sets. So a round portrait in a ring, 400px across,
with a 2px ring 12px out from the photograph, is the hero's tokens,
the radius set on its `bb-photo`, and the ring drawn on it:

<!-- from: test/support/guides/theming.css#ring -->
```css
:root {
  --bb-hero-photo-ratio: 1;
  --bb-hero-photo-max: 400px;
}

#page-hero .bb-photo {
  --bb-radius-photo: 50%;
  padding: 12px;
  border: 2px solid #b8913a;
  border-radius: 50%;
}
```

`#page-hero` is the hero's block, on every page, so photographs in
other sections stay as they were. The figure's width includes its
padding and its border, so `--bb-hero-photo-max` is the ring's outer
size, and the photograph is 372px across inside it. Put the ring in `app.css`, outside
every `@layer`, as for any hook CSS that draws.

A rule under the headline, or a dash before a list item's title, is
drawn this way: unlayered CSS on the hook, with a pseudo-element of
its own, as in `.bb-title::after { content: ""; display: block; … }`.
Make the pseudo-element a block, or a flex item, never inline, since a
hooked element may have whitespace at its edges, which an inline one
would sit beside. And keep the rule out of every `@layer`: the
utilities on the same element sit in Tailwind's `utilities` layer, and
only unlayered CSS beats them.

## Buttons and links

A stock renderer can't use the site's own components, so billboard
draws its buttons and links with `Billboard.Sections.Buttons`, from the
tokens, so they're right on any surface:

- `bb_button/1`, with `variant` `"primary"`, filled with `--bb-action`,
  or `"secondary"`, its words in `--bb-action-2` and its outline in
  `--bb-edge-2`, filled on hover with `--bb-action-2-hover`, its words
  then in `--bb-on-action-2-hover` ([Actions](#actions)). Given `href`, `navigate`, or `patch`, it draws a link. It has
  no disabled look and takes no form attributes, since stock sections
  draw only links and enabled buttons. Its words are in the button
  role, `bb-type-button`, so `--bb-button-size` and the rest of the
  role's tokens, in `theme.css`, set them.
- `bb_link/1`, with `tone` `"ink"`, for an ordinary link, in
  `--bb-link` and `--bb-link-hover`; `"accent"`, for the page's main
  action, in `--bb-accent`; or `"quiet"`, in `--bb-ink-soft`. `compact`
  drops its 44px tap height in a dense row.

A button's height, side room, and edge, and a link's line and its
offset, are tokens, read where `Billboard.Sections.Buttons` draws them
rather than in `theme.css`: `--bb-button-height`, `--bb-button-pad-x`,
`--bb-button-border`, `--bb-link-decoration`, and `--bb-link-offset`.
Each is drawn through an arbitrary value, which Tailwind sorts after
its named utilities, so a `class` of `px-8`, `min-h-14`, `border-0`, or
`underline-offset-2` loses. Change the geometry through the tokens
instead, which work for one element too, as in
`class="[--bb-button-pad-x:2rem]"`, or for every button in the tokens
file. A caller's `no-underline` still wins, but
`--bb-link-decoration: none` says the same.

## What the theme check enforces

Billboard's tests hold its own code to the theme, so a stock section
can't draw with one site's look:

- `theme.css` reads only `--bb-*` tokens, and names no colour of its
  own.
- The stock files, the renderers and what they're drawn from (the
  parts, blocks, words, buttons, glyphs, noise, and icons) and the
  page, name none of a site's classes: no colour that isn't billboard's
  (`text-white`, `bg-slate-100`), no face that isn't `font-bb-…`, no
  corner but the theme's four and `rounded-none`, and no type role,
  measure, surface, or hairline without the `bb-` prefix. They name no
  custom property but billboard's, even inside an arbitrary value; no
  hex colour, colour function, or named colour, in an arbitrary value
  or property; and none of Tailwind's own type utilities, such as
  `text-sm`, `font-bold`, `uppercase`, `tracking-wide`, or
  `leading-tight`, which the roles set. The glyphs, drawn at a fixed
  size, are spared the type check alone.
- The editor's files and `editor.css` draw only from the editor's own
  tokens, but for the page's gutter and section padding, and
  `editor.css` scopes every rule under `.bb-editor`.
- No file in `lib/` or `assets/` uses a utility's old name without its
  `bb-` prefix.

The check refuses what it names, what a site's classes look like,
without knowing any site's names: it's a guard, not an allowlist, so
it catches the mistakes it knows and passes anything else.

## The editor's own look

The editor draws its bar, outlines, labels, gaps, counter, marks,
controls, and the palette's glyphs from `editor.css`, which `app.css`
imports after the theme. It looks the same on every site, and never
takes on the site's faces or colours; the one exception is the page's
gutter and section padding, which it reads to line up with the page.

- Its tokens, the `--bb-edit-*` family, are set on `:root`, and its
  rules are scoped under `.bb-editor`, the class `billboard_editor`
  puts on the editor's container, so they touch nothing outside the
  editor.
- A site may change `--bb-edit-accent`, the editor's blue, and nothing
  else. `editor.css` sets it on `:root`, so set it after importing
  `editor.css`, in `app.css`.
- Its shadows are tokens too: `--bb-edit-shadow-popover`, a popover's,
  and `--bb-edit-shadow-palette`, the palette's.
- Its focus rule rings the editor's own controls in its blue: the bar,
  and what the editor marks as its own, such as the open section's
  header, the item and photograph tools, and the palette. A site's
  button in the open section isn't the editor's, and keeps the site's
  ring, in `--bb-focus`. Words typed in place ring in two tones: the
  blue, 2px out, with the editor's paper (`--bb-edit-paper`) between
  the ring and the words, so it reads on a dark page or a band.
- It names Work Sans for its type, and Cormorant Garamond for its
  glyphs, through `--bb-edit-font` and `--bb-edit-glyph-font`, which
  it leaves unset, so each falls back to those faces and then to the
  system's. It ships no font files: a site that loads those faces gets
  them, and another its own fallbacks.
- The palette's glyphs draw with their own utilities, such as
  `bg-bb-glyph-ink` and `border-bb-glyph-line`, from the
  `--bb-edit-glyph-*` tokens, as [Writing a component](writing-a-component.md)
  shows.
