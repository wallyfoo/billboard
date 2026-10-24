# Billboard

A page builder for Phoenix sites, built on Ash. A site's sections are
components, Ash embedded resources declared with `use Billboard.Component`.
Billboard knows what each one is to the builder: its palette entry, the
surfaces it may be drawn on, the values a site offers in its settings, and
the rules a page keeps. It also holds the page engine: each page's live
version and draft, editing and committing them, and the cache that
serves public pages.

Version 0.3.0 adds what sections are drawn with:

  * seven stock components, with their renderers (see Stock components);
  * the parts they're made of, `Billboard.Parts.Head`, `Action`, `Photo`,
    `Point`, `Detail`, and `Quote`, which a site's own components may
    hold too;
  * renderers, `use Billboard.Renderer`, and the pieces stock sections
    are drawn from, under `Billboard.Sections`: `Words`, `Parts`,
    `Blocks`, `Buttons`, `Glyph`, `Voronoi`, `Icons`, and `EditorFields`;
  * each component's editor fields and renderer, declared in its DSL;
  * the theme, `theme.css`, which draws every stock section from the
    site's `--bb-*` tokens, and `mix billboard.assets`, which links it
    into the site's assets;
  * `Billboard.Markdown`, the inline Markdown a site's words are written
    in, and `Billboard.Format`, the dates and shortened copy sections
    set;
  * `Billboard.Uploads`, which stores photographs, and
    `Billboard.Plugs.UploadsStatic`, which serves them.

The page itself, two-column and shared sections, the palette, and the
editor are still the site's, until they move into billboard (see What
the site still draws).

Billboard is pre-1.0, and its API may change between minor versions
until 1.0.

## Installation

Add it as a git dependency, pinned to a tag:

```elixir
def deps do
  [
    {:billboard, git: "https://github.com/wallyfoo/billboard.git", tag: "v0.3.0"}
  ]
end
```

Import its formatter rules in `.formatter.exs`, so `component` and
`editor` sections and the site's `page` and `library` entries format
without parentheses:

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
  alias Billboard.Components, as: Stock
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
    components: [Stock.Hero, Stock.Band, Stock.Points, MySite.Banner, Stock.News],
    surfaces: [%{name: "paper", label: "Paper"}, %{name: "band", label: "Band"}],
    offered: [page: ["paper"], stand_out: ["band"], card: []],
    starter: MySite.Pages.Starter,
    actions: MySiteWeb.Actions,
    context: MySite.Pages.Context,
    kinds: [news: [:free]],
    palette: [hints: [news: "The shop's latest news."], categories: [content: "Words"]],
    example_path: "/about"

  pages do
    page "/", "Home", kind: :free
    page "/services/:slug", "A service", kind: :service
  end
end
```

The answers new in 0.3.0, each optional:

  * `actions` names the site's `Billboard.Actions`: its own kinds of
    action, such as booking or ringing, and the component that draws
    them. Without it, an action is a link to a page on the site.
  * `context` names the site's `Billboard.Context`: the bindings a hero
    may take, and the choices the editor's pickers offer.
  * `kinds` keeps a component, by key, to some kinds of page, over the
    component's own `kinds`.
  * `palette` words the palette: `hints:`, by component key, over each
    component's own, and `categories:`, each category's label.
  * `example_path` is a page on the site, which the editor's hints give
    as an example. It's `"/about"` unless the site says.

Name the site module in `config/config.exs`:

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

A component's `component` section says what the builder knows about
it, and names its renderer; its `editor` section says how the editor
changes it, in the order the editor draws its fields.

```elixir
defmodule MySite.Banner do
  use Billboard.Component

  component do
    key :banner
    label "Banner"
    hint "One idea, set apart."
    category :band
    renderer MySiteWeb.Sections.Banner
    surface_kind :stand_out
    placeholder %{heading: "Your banner"}

    part :action, Billboard.Parts.Action
  end

  attributes do
    attribute :heading, :string, public?: true
    attribute :body, :string, public?: true
  end

  editor do
    words :heading, label: "Heading", limit: 60
    words :body, as: :markdown, label: "Words", limit: 200
    field :action, as: :part, part: :action, optional: true, item_label: "action"
  end
end
```

Billboard adds the `component` tag, the default actions, and the site's
options to it. `Billboard.Component` documents every option, parts, and
each kind of `words` and `field`.

The renderer is a module of function components: `render/1` draws a
section, and `glyph/1` its sketch in the palette.

```elixir
defmodule MySiteWeb.Sections.Banner do
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <h2 class="bb-type-heading text-bb-heading">
        {Words.text(@ctx, "heading", @content.heading)}
      </h2>
      <Parts.action :if={@content.action} action={@content.action} ctx={@ctx} prefix={@anchor} />
    </section>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
```

`Words.text/4` draws words as a visitor reads them, and, in the section
the editor has open, words to type into. `Billboard.Renderer` documents
what each callback is given, and what `use Billboard.Renderer` brings.

## The theme

Stock sections draw only through billboard's theme, `theme.css`, which
makes the site's `--bb-*` tokens Tailwind utilities, such as
`text-bb-ink` and `bb-type-heading`. The site sets the tokens on
`:root`, and a surface's own on its `bb-surface-NAME` class;
`theme.css` names each token it reads, with what it falls back to.

1. Run `mix billboard.assets` before Tailwind and esbuild, in the
   `assets.build` and `assets.deploy` aliases. It links billboard, from
   wherever Mix found it, into `assets/vendor/billboard`:

   ```elixir
   "assets.build": ["compile", "billboard.assets", "tailwind my_site", "esbuild my_site"],
   ```

   The development server's Tailwind watcher reads the link as it
   finds it, so a site that switches between a local checkout and the
   git dependency runs `mix assets.build` after the switch, or links
   afresh on every start in development:

   ```elixir
   "phx.server": if(Mix.env() == :dev, do: ["billboard.assets", "phx.server"], else: ["phx.server"]),
   ```

2. In `app.css`, import `theme.css` after the site's tokens, and let
   Tailwind read billboard's sections:

   ```css
   @import "./tokens.css";
   @import "../vendor/billboard/assets/css/theme.css";
   @source "../vendor/billboard/lib/billboard/sections";
   ```

3. Keep `assets/vendor/billboard` out of git, in `.gitignore`.

4. Plug `Billboard.Plugs.UploadsStatic` into the endpoint, before
   `Plug.Static`, so photographs are served under `/uploads`:

   ```elixir
   plug Billboard.Plugs.UploadsStatic
   ```

5. Say where photographs go, with a default in `config/config.exs` and,
   in production, `UPLOADS_DIR` in `config/runtime.exs`, on a volume
   that outlives a deploy:

   ```elixir
   # config/config.exs
   config :billboard, uploads_dir: Path.expand("../priv/uploads", __DIR__)

   # config/runtime.exs, for production
   config :billboard, uploads_dir: System.fetch_env!("UPLOADS_DIR")
   ```

Icons are Heroicons, drawn by the Heroicons Tailwind plugin a Phoenix
site has from `mix phx.new` (`@plugin "../vendor/heroicons"` in
`app.css`).

## Stock components

Seven components come with billboard, under `Billboard.Components`. A
site lists them in `components:` among its own:

| Component | Key | Reads from the page |
| --- | --- | --- |
| `Billboard.Components.Hero` | `:hero` | the context's `:bindings` |
| `Billboard.Components.Band` | `:band` | nothing |
| `Billboard.Components.Points` | `:points` | nothing |
| `Billboard.Components.TextMedia` | `:text_media` | nothing |
| `Billboard.Components.Details` | `:details` | the context's `:scope` |
| `Billboard.Components.Reviews` | `:reviews` | its reviews, in the page's data |
| `Billboard.Components.News` | `:news` | its posts, in the page's data |

The context is the site's (`Billboard.Context`), as the page's
`ctx.context`. Reviews and news posts are the site's too, by section
key in the page's `ctx.data`. Each component's renderer, from
`Billboard.Sections.Hero` to `Billboard.Sections.News`, says what it
draws, and the reviews' and the news's say what each row holds.

A site words a stock component's hint, and labels its category, through
`palette:`, keeps it to some kinds of page through `kinds:`, and narrows
its values through `options:` (`Billboard.SiteOptions`).

## What the site still draws

Until the page and the editor move into billboard, the site keeps:

  * the page: its sections in order, each through its renderer
    (`Billboard.Renderer.for!/1`), the hero in the page's hero block
    from `Billboard.Sections.Hero`'s slots, and the `ctx` each section
    is drawn with: its `site`, `context`, `data`, `surface`, and
    `joined`;
  * two-column and shared sections: the components with the `:columns`
    and `:shared` keys (`Billboard.Component`), and their renderers;
  * the palette, the section editor, the drawing of the fields that
    aren't typed in place, and the editor's hooks and styles, the
    `InlineWords` hook among them.

## Licence

MIT. See `LICENSE`.
