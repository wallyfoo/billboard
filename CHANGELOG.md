# Changelog

## v0.6.1

A site that takes a component out of `components:` no longer breaks
every page that stored one of its sections, and has a way to move or
delete those sections. Nothing changes for a site whose stored keys are
all ones it lists: there are no migrations, no codegen, and no new
Tailwind `@source` paths, and every page draws as it did on 0.6.0.

### Fixed

- A stored section whose key the site no longer lists, as when a site
  trades its own `:fees` for the stock `:prices`, made every read of
  its version fail (`binary_to_existing_atom("fees")` from
  `Ash.Type.Union`), so the visitor's page, the editor, and
  `put_page/3` all crashed. Such a section now reads as
  `%Ash.Union{type: :retired, value: %Billboard.Content.Retired{}}`,
  holding its key (`component`) and its stored fields (`fields`), and
  is written back as it was stored, so a draft copied from the live
  version keeps it.
- Visitors' pages draw nothing for it, and the sections either side
  meet; a column holding one draws its other column alone, and a
  Shared section placing one from the library draws nothing. Each time
  the pages cache is filled, at start-up and after each publish,
  billboard logs a warning naming the key, the page, and the section.
- The page editor draws a stand-in naming the key, which opens to a
  header with Remove, Up, Down, and Done, and nothing to edit.
- Publishing is refused while a page holds one: the rules give it an
  error, "this section's component, “fees”, is no longer on the site;
  remove the section to publish the page". Components' rules and the
  site's are never handed one. `put_page/3` replaces such a page as any
  other.

### Added

- `Billboard.Pages.migrate_sections/3`, and the domain's
  `migrate_sections/3`, which move every stored section of a key, in
  live versions, drafts, and the library, to another component, given
  its key or a function of each section's stored fields that returns
  `{key, fields}` or `:delete`, in one transaction, with `dry_run: true`
  to see what it would do. It returns each section it changed, with its
  page, version, key, and what it became, and refreshes the cache
  afterwards (Page kinds, "Retiring a component", with a worked example
  retiring the guide's Fees for Prices, and deleting them).
- `Billboard.Content.Retired`, what a section of a key the site no
  longer lists reads as, and `Billboard.Content.Retired.retired?/1`.

### Documented

- Page kinds' new "Retiring a component": what happens to a retired
  component's sections for visitors, in the editor, and on publish;
  moving them, mapping their fields; deleting them; and running the
  move from a script or a release. "Replacing a stock component" and
  Why the rules exist's "9. Keys are forever" link to it, and the usage
  rules name `migrate_sections/3`.
- `Billboard.Domain`'s moduledoc lists `migrate_sections/3`.

### Upgrading from 0.6.0

- Move the dependency's tag to `v0.6.1` and run `mix deps.get`.
  `mix ash.codegen --check` finds nothing to generate: the content
  union gains a type of its own, `:retired`, which is stored as JSON
  like the rest, and the site's section resource recompiles with it.
- A site with a component keyed `:retired` renames it, migrating its
  sections, since the content union now keeps that key; its content
  module fails to compile, naming the component, until it does.
- A site that has retired a component, or means to, moves its stored
  sections with `migrate_sections/3`, or deletes them with a function
  that returns `:delete`, `dry_run: true` first; or its admins remove
  each stand-in in the editor, and publish. Until then those pages
  can't be published.
- A site's own rules (`Billboard.Rule`) are never handed a retired
  section, so they need no change. Code of the site's own that reads
  sections itself, as a rule's helper or a page of its own does, meets
  `content.type == :retired` for one, and `Billboard.Content.Retired.retired?/1`
  says so.

## v0.6.0

A new stock component, and a new way to write `hide_when`. Nothing
changes for a site that doesn't use them: no stored section changes,
there are no migrations, no codegen, and no new Tailwind `@source`
paths, and every page draws as it did on 0.5.1.

### Added

- `Billboard.Components.Prices`, key `:prices`, a price list drawn by
  `Billboard.Sections.Prices` from rows the site's `Billboard.Data`
  module gives it: each an `id`, a `title`, a `price` the site has
  already formatted, and an optional `unit`, `note`, and `group`.
  Billboard never keeps or edits the prices. Its fields are an
  optional `head`, `body` (opening words), up to one action in
  `actions`, a `note` under the rows, a `group` (one of the site's
  `:scope` choices), which shows only that group's rows, and
  `this_page_only`, which shows only the page's scope's rows. It
  reads the page's `:scope`, fits in a column, and draws nothing with
  no rows to show, when the editor's stand-in says why (Page kinds,
  "The stock Prices section", and its row in "Each section's
  content").
- The `bb-price` hook, on each row of a price list (Theming, "Hooks
  for decoration", now twelve).
- `hide_when: [field: :any]` hides an editor entry while `field` holds
  anything at all, and shows it while it's nil or blank, as a
  `:choice` is when it's set to every one. A list of values works as
  before. The editor verifier refuses values that are neither a list
  nor `:any` (Writing a component, "Hiding an entry").
- `Billboard.Sections.EditorFields.hides?/2`, which says whether a
  `hide_when` entry's values hide a field.

### Documented

- `hide_when`'s exact shape, a keyword list of attributes, each with a
  list of values or `:any`, with examples (Writing a component,
  "Hiding an entry").
- The stock components' pickers read the context's `:scope` set of
  choices: Prices' "Group" and a detail's "Shows on" (Page kinds,
  "What a page is about"). The guide's example context now names its
  services `:scope`, and its data module gives Prices and the site's
  own Fees the same fees, in one read.

### Upgrading from 0.5.1

- Move the dependency's tag to `v0.6.0` and run `mix deps.get`.
  `mix ash.codegen --check` finds nothing to generate, since no
  resource the site holds changed.
- A site that wants the stock price list adds a clause for
  `%Billboard.Components.Prices{}` to its data module, giving rows in
  the shape `Billboard.Sections.Prices` documents, and then lists
  `Billboard.Components.Prices` in `use Billboard.Site`'s
  `components:`. Its "Group" picker offers the context module's
  `:scope` choices, so a site whose set has another name renames it
  `:scope`, in `choice_sets/0` and `choices/1`, or has no picker.
- A site with a component of its own keyed `:prices` keeps it, and
  can't list the stock one beside it, since no two components may
  share a key; nothing changes for it unless it replaces its own with
  the stock one, when its stored sections must hold the stock fields
  (Page kinds, "Replacing a stock component").
- The guide's Fees example now names a fee's service `group`, so the
  same rows draw in the stock Prices section. A site that copied the
  example needn't change its copy, which billboard never reads.

## v0.5.1

Every change keeps an existing site's look: a site that sets none of
the new tokens draws as it did on 0.5.0. There are no migrations, no
codegen, and no new Tailwind `@source` paths.

### Added

- The secondary button's outline, hover fill, and hover words have
  tokens of their own: `--bb-edge-2`, `--bb-action-2-hover`, and
  `--bb-on-action-2-hover`, falling back to `--bb-action-2`,
  `--bb-action-2`, and `--bb-on-action-2` (Theming, "Actions" and
  "Buttons and links").
- `--bb-font-quote`, the quote role's face, falling back to
  `--bb-font-heading` (Theming, "Type").
- A photograph's ratio, `--bb-photo-ratio` (4/3), for the hero and
  Text and image; the hero's alone, `--bb-hero-photo-ratio`; and the
  hero's photograph's widest, `--bb-hero-photo-max` (Theming, "Shape",
  and the round portrait in "Hooks for decoration").
- `Billboard.Pages.put_page/3`, and the domain's `put_page/3`, which
  make a page hold exactly the sections given and publish it, for
  seeds (Page kinds, "Pages from code"). `Billboard.Domain`'s moduledoc
  gives every function's arguments.
- The installer's `BillboardPageLive` hands each page its context, from
  `Billboard.Context.sample/1`, to `Billboard.Resolver.resolve/2` and
  to the page as `ctx` (Page kinds, "Handing a page its context").

### Documented

- The hairline tokens, `--bb-rule-width` and `--bb-rule-gap`, may be
  set on the `bb-section-head`, `bb-point`, or `bb-detail` hook to
  change one place's hairline (Theming, "One place's hairline").

### Upgrading from 0.5.0

- Move the dependency's tag to `v0.5.1` and run `mix deps.get`.
- A site that sets `--bb-edge-2`, `--bb-action-2-hover`, or
  `--bb-on-action-2-hover` on paper sets each to `initial` on its other
  surfaces and in both dark blocks, as the installed tokens file now
  does, or those surfaces inherit paper's value.
- A site with a context module brings its `BillboardPageLive` up to
  date by hand, since the installer never rewrites it: its `load/2`
  builds `context = Billboard.Context.sample(page)`, assigns it, and
  passes it to `Billboard.Resolver.resolve(version, context)`, and its
  `<Billboard.Sections.page>` takes `ctx={%{context: @context}}`. A
  site with none needs nothing.
