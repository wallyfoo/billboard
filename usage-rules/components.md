# Billboard components

A component is an embedded Ash resource (`use Billboard.Component`) and
a renderer (`use Billboard.Renderer`). Start one with
`mix billboard.gen.component MySite.Sections.Name`.

## The data module

`use Billboard.Component` sets `data_layer: :embedded`, and adds the
`component` tag, the default actions (read, create, update, and
destroy), and the site's options. Don't write any of them.

`component` section, one option each:

- `key`: the atom content is stored under. Never change it.
- `label`: the palette's name. Required.
- `hint`: the palette's one line. Required.
- `category`: its palette group. Required.
- `renderer`: the module that draws it.
- `kinds`: the page kinds it may go on, or `:all` (the default).
- `max`: how many a page may hold, or `nil` for any number.
- `column?`: whether it fits in a column.
- `mirror?`: whether it has image-left and image-right variants.
- `surface_kind`: its kind of surface, `:page` (the default) or
  another the site offers sections; never `:card`.
- `surface_from`: where it takes its surface when it doesn't choose
  one: `nil` (its own or its parent's), `:library`, or `:layout` (a
  hero).
- `placeholder`: what a new section starts with, only fields create
  accepts.
- `context`: the page's context entries its renderer reads, such as
  `[:scope]`.
- `rules`: its own rules, each a `Billboard.Component.Rule`.
- `filler?`: whether its placeholder is filler the editor warns about
  until it's written over (default true).

Parts, inside `component`:

- `part :name, Module`: one part; `allow_nil?` (default true) and
  `default`.
- `parts :name, Module`: a list; `min`, `max`, and `allow_nil?`
  (default false).

## The editor section

Entries draw in the order written. Every entry takes `label`, `hint`,
`hide_when` (`[field: [values]]`, hidden while `field` holds one of
them, or `[field: :any]`, while it holds anything), `more` (under
More…), and `bound` (`:hide` while a binding replaces the words).

- `words :name`: typed in place; a string attribute. `as: :text` (the
  default) or `:markdown`, `limit`, and `accent`.
- `field :name, as: …`, one of:
  - `:select`: `options` as `{label, value}`; `only_on` by page kind.
  - `:variants`: the section's layouts, from `options`.
  - `:toggle`: a checkbox.
  - `:number`: `min` and `max`.
  - `:note`: `text` and `link`, said in place of a field.
  - `:binding_note`: the note the section's binding gives.
  - `:part`: one part, `part:`, `optional`, and `except`.
  - `:list`: a list of parts, `part:`, `min`, `max`, `item_label`, and
    `except`.
  - `:photo`: a photograph, with `ratio`.
  - `:choice`: one of the site's choices, `from:` a set, or none.
  - `:choices`: several of them; one such field a component at most.
  - `:surface`: a card's surface.
  - `:shared`: one of the library's sections.

## Parts

- Stock parts by name: `:action`, `:link`, `:head`, `:quote`,
  `:point`, and `:detail`.
- A site's own: `use Billboard.Part`, with `part do blank %{…} end`
  and its own `editor`. It gets its id and actions.
- A hand-written part in a list needs `uuid_primary_key :id`, and every
  part a primary destroy action.

## The renderer

- `render/1` gets `section`, `content`, `anchor`, and `ctx`.
- The outer element takes `id={@anchor}`, `data-surface={@ctx.surface}`,
  and `class={Parts.section_class(@ctx)}`.
- Words go through `Billboard.Sections.Words.text/4` as
  `Words.text(@ctx, path, value)`, with the field's path, such as
  `"questions.0.title"`.
- `Billboard.Sections.Words.editing?/1` is true in the open section
  only.
- A list's items take `<Parts.item_tools>`.
- `glyph/1` draws the palette's sketch.
- `empty?/3` and `nothing_to_show/2` are optional: for a section that
  can draw nothing, and the editor's stand-in.
- A hero of the site's own draws only the inside of the page's hero
  block: no anchor, section class, or surface; start with `bb-wrap`;
  its component says `surface_from :layout`.

## Rules

- `Billboard.Component.Rule` checks one section; `Billboard.Rule` a
  page.
- `Billboard.Rule.error/2` holds Publish back;
  `Billboard.Rule.warning/2` doesn't.

## Data and context

- `Billboard.Data`: `fetch/3` per section, ending in a catch-all
  `:none`; `Billboard.Data.once/3` and `Billboard.Data.cached/3` read
  a thing once a page.
- The stock Reviews, News, and Prices draw the rows `fetch/3` gives
  them, and nothing without; list each in `components:` once the data
  module has a clause for it. For a price list, use the stock
  `Billboard.Components.Prices` (its renderer,
  `Billboard.Sections.Prices`, lists a row's fields) before writing
  one: its `group` picks from the context's `:scope` choices.
- `Billboard.Context`: `bindings/0`, `choice_sets/0` with `choices/1`
  (both or neither), `sample/1`, and `path/2`.
- `Billboard.Layout`: the site's chrome, `page/1` and `site/0`.

## Testing

- `use Billboard.ComponentCase, endpoint: MySiteWeb.Endpoint, repo: MySite.Repo`
- `assert_component_works(MySite.Sections.Name, data: rows, context: %{scope: "…"})`
