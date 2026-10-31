# Billboard

A page builder for Phoenix sites, built on Ash. A site's sections are
components, Ash embedded resources declared with `use Billboard.Component`.
Billboard knows what each one is to the builder: its palette entry, the
surfaces it may be drawn on, the values a site offers in its settings, and
the rules a page keeps. It also holds the page engine: each page's live
version and draft, editing and committing them, and the cache that
serves public pages.

Billboard is pre-1.0, and its API may change between minor versions
until 1.0.

## Installation

Add billboard and Ash to `mix.exs` together, at the top of the list in
`deps/0`:

```elixir
      {:billboard, git: "https://github.com/wallyfoo/billboard.git", tag: "v0.5.0"},
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:igniter, "~> 0.8", only: [:dev, :test]},
```

Then fetch them, install Ash, and install billboard:

```bash
mix deps.get
mix compile
mix igniter.install ash ash_postgres ash_phoenix --yes
mix billboard.install --home --yes
```

[Getting started](guides/getting-started.md) takes a new Phoenix site
from here to its first published page.

## Start here

- [Getting started](guides/getting-started.md): install billboard, and
  edit and publish the first page.
- [Writing a component](guides/writing-a-component.md): a section of
  the site's own, from the generator to its test.
- [Parts reference](guides/parts.md): the stock parts a component
  holds, and a site's own.
- [Theming](guides/theming.md): the tokens, surfaces, utilities, and
  hooks that make billboard's pages look like the site's.
- [Page kinds and bound sections](guides/page-kinds-and-bound-sections.md):
  page kinds, data a section reads, what a page is about, and replacing
  a stock component.
- [Why the rules exist](guides/why-the-rules-exist.md): each check
  billboard makes, and what it protects.

## Generators

- `mix billboard.install` installs billboard in a Phoenix site on Ash.
- `mix billboard.gen.component MySite.Sections.Name` writes a
  component, its renderer, and its test.
- `mix billboard.assets` links billboard's theme and hooks into the
  site's assets.

## Usage rules

Billboard ships `usage-rules.md`, with `components` and `theme`
sub-rules, for the `usage_rules` package to give a coding agent.

## Licence

MIT. See `LICENSE`.
