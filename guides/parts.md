# Parts reference

This guide lists billboard's parts: the pieces a component holds, such
as a section's head, a button, or a photograph, which billboard's editor
knows how to change. For each, it gives the fields, what the editor
shows for them, what a new one starts as, what draws it, and the stock
components that hold it. At the end you'll know which part fits a
component's field, and when a list needs a part of the site's own.

## What a part is

A part is an Ash embedded resource that a component holds: one, with
`part :head, Billboard.Parts.Head` in its `component` section, or a
list, with `parts :points, Billboard.Parts.Point, min: 1, max: 4`. The
component's `editor` names it in a `field`, `as: :part` for one or
`as: :list` for a list, by its name, as in
`field :head, as: :part, part: :head, optional: true, item_label: "heading"`.
Billboard's editor knows how to change each of its own: it reads the
part's editor fields from `Billboard.Sections.Parts.editor_fields/1`,
and builds a new one from `Billboard.Sections.Parts.blank/1`.

Billboard has six part modules, and seven names for them
(`Billboard.Sections.Parts.parts/0`): `:head`, `:action`, `:link`,
`:photo`, `:point`, `:detail`, and `:quote`. `:link` has no module of
its own: it's an action that can only be a link, as a point's is.

What the editor shows depends on how the section draws a field:

- **Words** (a field with no `as`, or `as: :markdown`) are typed in
  place, where the section draws them through
  `Billboard.Sections.Words.text/4`, at the field's path: `head.heading`,
  or `points.0.title` for the first point's title. The stock sections
  draw an empty optional field in the open section too, to be typed
  into. `limit` is a soft limit, which the editor counts against and
  warns past, and `accent` gives a hint about italics.
- **A button**, an action or a link, opens its popover when it's
  clicked in the open section, where its fields are changed or the
  button is taken away. A section that may take another shows "Add a
  button" (or "Add a link") where the next would go.
- **Everything else** is drawn in the open section, on the item or over
  the photograph, or in the controls header.

A part a component makes optional (`optional: true`), such as Details'
head, is added from the controls header ("Add a heading", from its
`item_label`), and taken away under More ("Remove the heading"). An
optional action is added and taken away where it's drawn, as above.

A part that sits in a list has `uuid_primary_key :id`, so the stock
parts that do (the action, the point, and the detail) have one, and the
head, the photograph, and the quote, which sit alone, don't. Every stock
part has a primary read, create, update, and destroy action.
[Why the rules exist](why-the-rules-exist.md) says why.

## Head (`Billboard.Parts.Head`)

A section's head: a hairline, an optional eyebrow, the heading, and at
most one action opposite it.

| Field | Type | What it's for | Default |
| --- | --- | --- | --- |
| `eyebrow` | `:string` | the short line above the heading, up to 40 characters | none |
| `heading` | `:string` | the section's heading, up to 120 characters; required | none |
| `action` | `Billboard.Parts.Action` | the one action opposite the heading | none |

| The editor shows | For | How | Limit |
| --- | --- | --- | --- |
| Eyebrow | `eyebrow` | typed in place; drawn as "Eyebrow (optional)" while it's empty | 30 |
| Heading | `heading` | typed in place, with the hint about italics | 60 |
| Its action | `action` | the button, which opens its popover; "Add a button" while there's none | |

A new head is `%{"heading" => "Your heading"}`.

`Billboard.Sections.Parts.head/1` draws it, through
`Billboard.Sections.Blocks.section_head/1`: the heading is an `h2`, and
the wrapper, the eyebrow, and the heading carry the `bb-section-head`,
`bb-eyebrow`, and `bb-heading` hooks ([Theming](theming.md)). A section
with no head draws none.

Details, Points, and Prices take a head they can do without; Prices'
starts as "Prices" when it's added from the palette. Text and image,
Reviews, and What's on always have one; Reviews' starts as "What
clients say".

## Action (`Billboard.Parts.Action`)

A button or a text link, which goes to a page on the site or does
something of the site's own ([The action's kinds](#the-action-s-kinds)).

| Field | Type | What it's for | Default |
| --- | --- | --- | --- |
| `kind` | `:atom` | where it goes: `:link`, to `path`, or one of the site's own kinds | `:link` |
| `style` | `:atom` | how it looks: `:primary`, `:secondary`, or `:text` | `:secondary` |
| `label` | `:string` | its words, up to 40 characters | none |
| `path` | `:string` | for a link, an address on the site, up to 200 characters | none |

A link needs a label and an address, and the address must be on the
site: a path starting with one slash, such as the one
`Billboard.Site.example_path/0` gives. A kind must be one the site
offers, which is checked only when it changes.

| The editor shows | For | How | Limit |
| --- | --- | --- | --- |
| Goes to | `kind` | a select of the kinds the site offers, in its order, each on the kinds of page it allows | |
| Looks like | `style` | a select: Primary button, Secondary button, or Text link | |
| Words | `label` | a field, with the site's hint under it if it gives one; left out for a kind the site words itself | 24 |
| Address | `path` | a field, with the example path in its hint; only for a link | |
| A note | | "The site words this one itself, from its settings.", only for a kind the site words itself | |

All of them are in the button's popover. A new action is
`%{"kind" => "link", "style" => "secondary", "label" => "Your link", "path" => "/"}`.

`Billboard.Sections.Parts.action/1` draws one, by its kind, in the
colours of the surface it sits on: a link as `bb_button/1`, primary or
secondary, or as `bb_link/1` for `:text` (`Billboard.Sections.Buttons`);
any other kind by the site's `action/1`; and a kind the site no longer
offers as nothing. `Billboard.Sections.Parts.action_group/1` draws a
row of them, and offers another while there are fewer than the
section's `max`. In the open section,
`Billboard.Sections.Parts.editable_action/1` marks each, so a click
opens its popover rather than following it.

The hero takes up to three, which `Billboard.Sections.Hero.actions/1`
draws in the hero's row; Text and image up to two, and Prices one, in
`action_group/1`; Band one; and a head one. A section with more than
one primary action has a warning (`Billboard.Rules`).

### A link (`:link`)

`:link` is an action that can only be a link: its `kind` is `:link`,
and the editor shows only its words and its address. A point's link is
one.

| The editor shows | For | How | Limit |
| --- | --- | --- | --- |
| Link words | `label` | a field in the link's popover | 24 |
| Address | `path` | a field, with the example path in its hint | |

A new link is `%{"label" => "Your link", "path" => "/"}`.

## Photo (`Billboard.Parts.Photo`)

A photograph, or the placeholder that stands in for one until it's put
in.

| Field | Type | What it's for | Default |
| --- | --- | --- | --- |
| `label` | `:string` | what the shot shows, drawn on the placeholder, up to 80 characters; required | none |
| `path` | `:string` | the upload, under `/uploads`, where `Billboard.Uploads` serves it | none |
| `alt` | `:string` | the upload's description, for people who can't see it, up to 160 characters; required once there's an upload | none |

The path must be an upload, not a link to a photograph elsewhere.

It has no editor fields of its own (`editor_fields(:photo)` is `[]`).
A component names it with `field :photo, as: :photo, ratio: "aspect-[4/3]"`,
and the open section draws its tools over it:

| The editor shows | What it does |
| --- | --- |
| Remove | takes the photograph away, while there's one, so the placeholder shows |
| Describe | opens a popover with What it shows, the label, and Description, the words read aloud for it |
| Add a photograph, or Replace | picks a file to upload, which saves once it has arrived |

A new photograph is `%{"label" => "What the photograph shows"}`.

`Billboard.Sections.Blocks.photo/1` draws it: a figure with the
`bb-photo` hook, at the ratio the component gives, holding the upload,
cropped to fill, or, with none, Voronoi noise in the site's noise
colours, seeded by the label, with the label over it.
`Billboard.Sections.Parts.editable_photo/1` puts the tools over it in
the open section.

The hero (`Billboard.Sections.Hero.media_slot/1`) and Text and image
each hold one, at 4:3, drawn in their layouts with a photograph.

## Point (`Billboard.Parts.Point`)

One of a row of short points.

| Field | Type | What it's for | Default |
| --- | --- | --- | --- |
| `title` | `:string` | the point's title, up to 60 characters; required | none |
| `body` | `:string` | its words, up to 600 characters | none |
| `link` | `Billboard.Parts.Action` | a link to a page on the site, never one of the site's own kinds | none |
| `surface` | `:string` | in the cards look, the surface its card is drawn on, one the site offers cards, or none for its section's | none |

| The editor shows | For | How | Limit |
| --- | --- | --- | --- |
| Title | `title` | typed in place, with the hint about italics | 40 |
| Words | `body` | typed in place, as Markdown; drawn as "Words (optional)" while it's empty | 240 |
| Its link | `link` | a `:link`, which opens its popover; "Add a link" while there's none | |
| Ground | `surface` | a select on the card, in the cards look, where the site offers cards a surface: "Same as the section", or one of them | |

The item's tools move a point up or down, and remove it while the list
has more than its fewest. A new point is `%{"title" => "Your point"}`.

Points draws them itself (`Billboard.Sections.Points`), one to four:
each under a hairline, or, in the cards look, as a `bb-card`, with the
`bb-point` hook, and its title with `bb-item-title`, an `h3` under a
head and an `h2` without one. A point's link is always a text link.
[Its source](https://github.com/wallyfoo/billboard/blob/v0.6.0/lib/billboard/sections/points.ex)
is the stock example of a list of parts with their tools.

## Detail (`Billboard.Parts.Detail`)

One labelled detail, such as "Parking".

| Field | Type | What it's for | Default |
| --- | --- | --- | --- |
| `label` | `:string` | the detail's label, up to 40 characters; required | none |
| `body` | `:string` | what a visitor should know, up to 600 characters; required | none |
| `only_for_group` | `:string` | the page scope it shows on alone, or none for every page | none |

| The editor shows | For | How | Limit |
| --- | --- | --- | --- |
| Label | `label` | typed in place | 30 |
| Words | `body` | typed in place, as Markdown | 300 |
| Shows on | `only_for_group` | a select on the item, of the site's `:scope` choices, where the site's context gives them | |

`only_for_group` is matched against the page's scope
(`ctx.context.scope`), which a site's context gives
([Page kinds and bound sections](page-kinds-and-bound-sections.md)).
A visitor sees the details for every page and those for the page's
scope. The open section shows them all, so each can be changed whichever
page it's for, and fades those for another scope. A new detail is
`%{"label" => "Your label", "body" => "What a visitor should know."}`.

Details draws them itself (`Billboard.Sections.Details`), one to twelve,
as rows between hairlines, each with the `bb-detail` hook and its label
with `bb-item-title`.

## Quote (`Billboard.Parts.Quote`)

A pull quote: what was said, and, if you like, who said it and a line
about them.

| Field | Type | What it's for | Default |
| --- | --- | --- | --- |
| `body` | `:string` | what was said, up to 400 characters; required | none |
| `name` | `:string` | who said it, up to 40 characters | none |
| `meta` | `:string` | a line about them, such as when or for what, up to 40 characters | none |

| The editor shows | For | How | Limit |
| --- | --- | --- | --- |
| Quote | `body` | typed in place, as Markdown | 200 |
| Who said it | `name` | typed in place, as plain words; drawn as "Who said it (optional)" while it's empty | 30 |
| About them | `meta` | typed in place, as plain words; drawn as "About them (optional)" while it's empty | 30 |

A new quote is `%{"body" => "Your quote"}`.

`Billboard.Sections.Parts.quote_figure/1` draws it, through
`Billboard.Sections.Blocks.band/1`'s quote: the words at quote size in
the heading's ink, with the `bb-quote` hook, and the name in the
subheading's. Band holds one, in its quote layouts, and the editor
leaves it out of the heading layout. Reviews draws each review with
`quote_figure/1` too, from the rows its data gives, not from this part.

## The action's kinds

`:link` is billboard's: an action of kind `:link` goes to its `path`.
Every other kind is the site's own, such as booking or ringing, which
the site lists and draws in a module of its own, named in
`use Billboard.Site` as `actions: MySiteWeb.Actions`. The module's
`kinds/0` lists them, in the order "Goes to" offers them, each with its
`label`, `words: :site` when the site words the button itself (so the
editor leaves out its words and shows the note), and `only_on`, the page
kinds it goes on when it doesn't go on every kind. Its `action/1` draws
each, given the action, the section's `ctx`, and `prefix`, the prefix of
its section's ids, and its optional `label_hint/0` is the hint under a
button's words. `:link` comes first, unless the site lists it, as
`link: []`, among its own.

A site with no actions module has links alone, and the installer writes
none. When a site stops listing a kind, an action saved with it keeps
it, and still saves an edit to its words, until someone changes it; it
draws nothing meanwhile. A point's link is never one of the site's
kinds. `Billboard.Actions` has a worked example: a "Call us" button the
site words itself, from its phone number.

## A part of the site's own

When a list's items aren't one of these, write a part for them, with
`use Billboard.Part`: an embedded resource with an `editor` section, in
a component's terms, and the `blank` a new item starts as. A component
names it by its module where it names a stock part by its name, as in
`field :questions, as: :list, part: MySite.Sections.Faq.Question`.
[Writing a component](writing-a-component.md) builds one, a FAQ's
question, and `Billboard.Part` says what its editor may hold: an item's
tools change words, selects, toggles, numbers, a choice, a surface, and
a part, and show notes, while a photograph, variants, a list, several
choices, and `bound:` belong to a section.
