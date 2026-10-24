# Billboard

A page builder for Phoenix sites, built on Ash. A site's sections are
components, Ash embedded resources declared with `use Billboard.Component`.
Billboard knows what each one is to the builder: its palette entry, the
surfaces it may be drawn on, the values a site offers in its settings, and
the rules a page keeps. It also holds the page engine: each page's live
version and draft, editing and committing them, and the cache that
serves public pages.

Version 0.4.0 adds the page and its editor:

  * the page, `Billboard.Sections.page/1`, which draws a version's
    sections in the site's own layout (`Billboard.Layout`);
  * two more stock components, Two columns and Shared (see Stock
    components);
  * `Billboard.Resolver`, which reads the rows the page's sections draw,
    such as reviews and news, once per page, through the site's
    `Billboard.Data`;
  * the page editor, `Billboard.EditorLive`, which a site mounts in its
    own router with `billboard_editor` (see The editor): the page as
    visitors see it, words typed where they sit, a section editor, a
    palette of components, its own buttons, inputs, and messages, its
    stylesheet, `editor.css`, and its hooks, which `mix billboard.assets`
    links into the site's assets with the theme.

Version 0.3.0 added what sections are drawn with:

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

The site draws its own layout, its own components, and its pages' data
(see The site); billboard draws the rest of the page, and the editor.

Billboard is pre-1.0, and its API may change between minor versions
until 1.0.

## Installation

Add it as a git dependency, pinned to a tag:

```elixir
def deps do
  [
    {:billboard, git: "https://github.com/wallyfoo/billboard.git", tag: "v0.4.0"}
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
    data: MySite.Pages.Data,
    layout: MySiteWeb.Layouts,
    page_events: ~w(filter),
    kinds: [news: [:free]],
    palette: [hints: [news: "The shop's latest news."], categories: [content: "Words"]],
    example_path: "/about"

  pages do
    page "/", "Home", kind: :free
    page "/services/:slug", "A service", kind: :service
  end
end
```

The answers new in 0.4.0:

  * `layout` names the site's `Billboard.Layout`: its chrome, the header
    and footer the page is drawn in, for visitors and in the editor
    alike, and `site/0`, the site's own data the layout draws from in
    the editor. The page and the editor need it.
  * `data` names the site's `Billboard.Data`: what the sections that
    draw rows from outside the builder, such as reviews and news, read
    for each page. Without it, they draw none.
  * `page_events` lists the events the site's own page components send,
    such as a filter's, which the editor draws them sending and does
    nothing with (see The editor).

The site's `Billboard.Context` may also answer two more, for the editor:
`sample/1`, what a page whose route has a parameter is drawn about in
the editor, such as the first service for `/services/:slug`, and
`path/2`, the address that draws a page about such a context, such as
`"/services/repairs"`, which the editor hands the layout as the address
drawn. Without `sample/1`, such a page is drawn about nothing in
particular; without `path/2`, a page's address is its pattern, and a
page whose route has a parameter has none.

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

### The layout, the data, and a page

The layout is a module of the site's with `@behaviour Billboard.Layout`.
Its `page/1` is a function component that draws the site's header and
footer round two slots: `hero`, the page's hero block, which it wraps
in the hero's surface, and `inner_block`, the other sections, in
`<main>`. Its `site/0` is the site's own data, which the editor hands
it:

```elixir
defmodule MySiteWeb.Layouts do
  use MySiteWeb, :html
  @behaviour Billboard.Layout

  attr :flash, :map, required: true
  attr :site, :map, required: true
  attr :current_path, :string, default: nil
  attr :editing, :boolean, default: false
  slot :hero, required: true
  slot :inner_block, required: true

  @impl true
  def page(assigns) do
    ~H"""
    <header>…</header>
    <div class="bb-surface-band">{render_slot(@hero)}</div>
    <main>{render_slot(@inner_block)}</main>
    <footer>…</footer>
    <.flash_group :if={!@editing} flash={@flash} />
    """
  end

  @impl true
  def site, do: %{settings: MySite.settings!()}
end
```

`editing` is true in the editor, which draws its own bar and messages,
so the layout then draws no messages, and nothing fixed over the page.
`Billboard.Layout` documents what `page/1` is given.

The data module answers `fetch/3` for each of a page's sections, and
reads each thing once per page with `Billboard.Data.once/3`;
`Billboard.Data` has an example. A site's LiveView draws a page with
both:

```heex
<Billboard.Sections.page
  version={@version}
  data={@data}
  ctx={%{context: @context}}
  site={@site}
  flash={@flash}
  current_path={@current_path}
/>
```

where `@version` is `MySite.Pages.page_for(pattern)`, `@context` what
the page is about (`Billboard.Context`), `@data` its sections' rows,
`Billboard.Resolver.resolve(@version, @context)`, and `@site` the
site's own data, which its layout and its own sections read. `Billboard.Sections`
documents the rest of what a section is drawn with.

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
   Tailwind read the files billboard draws classes in: its sections,
   the page, and the editor:

   ```css
   @import "./tokens.css";
   @import "../vendor/billboard/assets/css/theme.css";
   @source "../vendor/billboard/lib/billboard/sections";
   @source "../vendor/billboard/lib/billboard/sections.ex";
   @source "../vendor/billboard/lib/billboard/editor_live.ex";
   @source "../vendor/billboard/lib/billboard/editor_live";
   @source "../vendor/billboard/lib/billboard/editor";
   ```

   Name these five, not all of billboard: Tailwind builds a utility
   from every word it reads that names one, and the words in
   billboard's other code and docs would build stray ones, such as
   `.table` and `.shrink`.

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

## The editor

The page editor is a LiveView, `Billboard.EditorLive`. Mount it in the
site's router, inside the `live_session` the site's signed-in admin
pages use, so it runs that session's `on_mount` and has its
`@current_scope`. It acts as `current_scope.user`:

```elixir
import Billboard.Editor.Router

scope "/admin", MySiteWeb.Admin do
  pipe_through [:browser, :require_authenticated_user]

  live_session :admin, on_mount: [{MySiteWeb.UserAuth, :require_authenticated}] do
    billboard_editor "/pages", back: {"Admin", "/admin"}
  end
end
```

`back` is the editor bar's way out, its words and where it goes. The
editor checks no permission of its own: anyone the `live_session` lets
in can edit and publish every page. Its addresses are
`Billboard.Editor.path/3`'s, from the route:
`Billboard.Editor.path(MySiteWeb.Router, "/", open: "hero")` is
`"/admin/pages?open=hero&page=%2F"`, the home page with its hero open.

Its hooks come from billboard, through the link `mix billboard.assets`
makes and the colocated hooks LiveView writes for billboard. In
`app.js`:

```js
import {hooks as colocatedHooks} from "phoenix-colocated/my_site"
import {hooks as billboardHooks} from "phoenix-colocated/billboard"
import {EditCanvas, InlineWords} from "../vendor/billboard/assets/js/billboard.js"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {...colocatedHooks, ...billboardHooks, EditCanvas, InlineWords},
  // ...
})
```

esbuild finds `phoenix-colocated/billboard` under the build path, which
a site from `mix phx.new` already gives it in `NODE_PATH`.

Its stylesheet goes in `app.css`, after `theme.css`:

```css
@import "../vendor/billboard/assets/css/editor.css";
```

It draws the editor's chrome from its own `--bb-edit-*` tokens, never
the site's, so the editor looks the same on every site, and scopes
every rule under `.bb-editor`, the class `billboard_editor` puts on the
editor's container, so it touches nothing outside the editor. A site
may change `--bb-edit-accent`, the editor's blue. The editor names Work
Sans for its type and Cormorant Garamond for the palette's glyphs,
falling back to the system's faces; it ships no fonts, so a site that
loads these faces gets them, and `--bb-edit-font` and
`--bb-edit-glyph-font` name others.

Photographs uploaded in the editor (JPEG, PNG, or WebP, up to 15 MB)
are stored by `Billboard.Uploads`, in the site's `uploads_dir`, and
served by `Billboard.Plugs.UploadsStatic`, both set up under The theme.

A site's own page components may send events of their own, such as a
filter's, which the editor draws them sending. List them in
`page_events:`, and the editor does nothing with them. For any other
event it doesn't know, it does nothing and logs a warning naming it, so
a mistyped one is seen:

```text
The page editor got an event it doesn't know, "filtre". If the site's page sends it, add it to `page_events:` in `use Billboard.Site`; otherwise handle it.
```

## Stock components

Nine components come with billboard, under `Billboard.Components`. A
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
| `Billboard.Components.Columns` | `:columns` | its children, the sections in its two columns |
| `Billboard.Components.Shared` | `:shared` | the library section its key names |

The context is the site's (`Billboard.Context`), as the page's
`ctx.context`. Reviews and news posts are the site's too, by section
key in the page's `ctx.data`. Each component's renderer, from
`Billboard.Sections.Hero` to `Billboard.Sections.Shared`, says what it
draws, and the reviews' and the news's say what each row holds. Two
columns holds two sections of components that fit in a column (their
`column?`, `Billboard.Component`), and Shared shows a section of the
shared library, edited there.

A site words a stock component's hint, and labels its category, through
`palette:`, keeps it to some kinds of page through `kinds:`, and narrows
its values through `options:` (`Billboard.SiteOptions`).

## Licence

MIT. See `LICENSE`.
