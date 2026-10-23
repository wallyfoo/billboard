# Billboard

A page builder for Phoenix sites, built on Ash. A site's sections are
components, Ash embedded resources declared with `use Billboard.Component`.
Billboard knows what each one is to the builder: its palette entry, the
surfaces it may be drawn on, the values a site offers in its settings, and
the rules a page keeps. It also holds the page engine: each page's live
version and draft, editing and committing them, and the cache that
serves public pages.

Billboard is pre-1.0. It grows with the needs of Stylish Strands, its
first site, and its API may change between minor versions until 1.0.

## Installation

Add it as a git dependency, pinned to a tag:

```elixir
def deps do
  [
    {:billboard, git: "https://github.com/wallyfoo/billboard.git", tag: "v0.2.0"}
  ]
end
```

Import its formatter rules in `.formatter.exs`, so `component` sections
and the site's `page` and `library` entries format without parentheses:

```elixir
[
  import_deps: [:ash, :billboard],
  # ...
]
```

## The site

The site describes itself in one module, `use Billboard.Site`: its
answers, given as options, and its pages, in a `pages` section.

```elixir
defmodule MySite.Billboard do
  alias MySite.Pages

  use Billboard.Site,
    otp_app: :my_site,
    repo: MySite.Repo,
    pubsub: MySite.PubSub,
    domain: Pages,
    resources: [
      page: Pages.Page,
      version: Pages.Version,
      section: Pages.Section,
      content: Pages.Content
    ],
    components: [MySite.Banner],
    surfaces: [%{name: "paper", label: "Paper"}, %{name: "band", label: "Band"}],
    offered: [page: ["paper"], stand_out: ["band"], card: []],
    starter: MySite.Pages.Starter

  pages do
    page "/", "Home", kind: :free
    page "/services/:slug", "A service", kind: :service
  end
end
```

Name it in `config/config.exs`:

```elixir
config :billboard, site: MySite.Billboard
```

`Billboard.Site` documents every answer, the pages, and the callbacks
it defines from them.

### The site's modules for its pages

The page record, versions, sections, content union, and domain are the
site's own modules, each a single `use`. Billboard writes everything
inside them, from the site's answers:

```elixir
defmodule MySite.Pages.Page do
  use Billboard.Page, site: MySite.Billboard
end

defmodule MySite.Pages.Version do
  use Billboard.Version, site: MySite.Billboard
end

defmodule MySite.Pages.Section do
  use Billboard.Section, site: MySite.Billboard
end

defmodule MySite.Pages.Content do
  use Billboard.Content, site: MySite.Billboard
end

defmodule MySite.Pages do
  use Billboard.Domain, site: MySite.Billboard
end
```

Each module goes in a file of its own. The page record, versions, and
sections take `table:` to name their tables, which default to
`billboard_pages`, `billboard_versions`, and `billboard_sections`.

List the domain among the site's Ash domains:

```elixir
config :my_site, ash_domains: [MySite.Pages]
```

Start `Billboard.Cache`, which holds what each page shows visitors, in
the application's supervision tree, after the repo and PubSub:

```elixir
children = [
  MySite.Repo,
  {Phoenix.PubSub, name: MySite.PubSub},
  Billboard.Cache,
  MySiteWeb.Endpoint
]
```

Then `mix ash.codegen add_billboard_pages` writes the migrations for the
tables, and `mix ash.migrate` runs them.

The domain carries the engine's functions, so the site calls
`MySite.Pages.page_for("/")` for what a page shows visitors, and
`MySite.Pages.change_draft/3` for an editor's change. `Billboard.Pages`
documents them.

## A component

```elixir
defmodule MySite.Banner do
  use Billboard.Component

  component do
    key :banner
    label "Banner"
    hint "One idea, set apart."
    category :band
    placeholder %{heading: "Your banner"}
  end

  attributes do
    attribute :heading, :string, public?: true
  end
end
```

Billboard adds the `component` tag, the default actions, and the site's
options to it. `Billboard.Component` documents every option, and parts.

## Licence

MIT. See `LICENSE`.
