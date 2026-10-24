# Getting started

This guide turns a new Phoenix site into one whose pages are written in
place. At the end you'll have a home page drawn by billboard, an editor
at `/admin/pages` that signed-in users open, and a first heading you
typed and published.

## What you'll have

The editor draws the page as visitors see it, under a slim bar. Click a
section to open it, and type into its words where they sit. Every change
saves to a draft as you type, at each pause, and visitors see only what
was last published. Publish puts the page's whole draft on the site, and
Discard drops it, so each acts on the whole page, never on one section.
The editor checks the page as it changes: while a section breaks a rule,
it holds Publish back and says what to fix, and it warns of filler, the
words a new section arrives with, until they're written over.

## Before you start

You need Elixir 1.16 or later, PostgreSQL, and two archives, Phoenix's
and Igniter's:

```text
mix archive.install hex phx_new
mix archive.install hex igniter_new
```

## A new site

Make the site, and give it a way to sign in:

<!-- run -->
```bash
mix phx.new my_site --install
cd my_site
mix phx.gen.auth Accounts User users --live
```

Billboard's editor needs a signed-in `live_session`, since it acts as
the session's signed-in user. `mix phx.gen.auth` makes one,
`live_session :require_authenticated_user`, and the installer mounts the
editor there. A site that signs users in its own way names its own
session, with `mix billboard.install --live-session NAME`.

## The dependencies

Add billboard and Ash to `mix.exs` together, at the top of the list in
`deps/0`:

<!-- site: mix.exs -->
```elixir
      billboard(),
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:igniter, "~> 0.8", only: [:dev, :test]},
```

and, after `deps/0`, the function that names billboard:

<!-- site: mix.exs -->
```elixir
  # Billboard is pinned to a tag, so what's deployed is always a tag.
  # BILLBOARD_PATH points it at a local checkout while working on both.
  defp billboard do
    case System.get_env("BILLBOARD_PATH") do
      nil -> {:billboard, git: "https://github.com/wallyfoo/billboard.git", tag: "v0.5.0"}
      path -> {:billboard, path: path}
    end
  end
```

The switch has a function of its own because Igniter, which Ash's
installers run on, adds to `deps/0` only when the function is its list
alone. The requirements are the ones Ash's installer writes, so it
leaves them as they are; billboard's own ask for Ash 3.33, AshPostgres
2.13, and AshPhoenix 2.3 or later. Then fetch them, compile, and install
Ash:

<!-- run -->
```bash
mix deps.get
mix compile
mix igniter.install ash ash_postgres ash_phoenix --yes
```

Compile before Ash's installers run, so they don't compile new
dependencies as they go: when they do, they can stop part way with a
`Protocol.UndefinedError`, and running the command again finishes.

`BILLBOARD_PATH` builds the site against a local checkout of billboard
instead of the tag. A build made with it set mustn't be deployed, since
`mix.lock` still names the tag, so what was built isn't what the lock
says. [Working on billboard too](#working-on-billboard-too) makes
`mix precommit` refuse it.

## Install billboard

<!-- run -->
```bash
mix billboard.install --home --yes
mix ash.codegen add_billboard
mix ecto.create
mix ecto.migrate
```

`mix ash.codegen add_billboard` warns that the migration includes
destructive operations. That's expected of this first one: it creates
`billboard_sections` before `billboard_versions`, then adds the foreign
key between them with a `modify`, which AshPostgres counts as
destructive. It drops nothing.

`--home` routes `/` to billboard in place of phx.new's home page, so
phx.new's test of that page fails, as the installer's notice says.
Delete `test/my_site_web/controllers/page_controller_test.exs`, and
`PageController` once nothing else uses it.

The rest of this section is what the installer wrote, file by file. It
leaves alone anything that's there already, so it's safe to run again.

### The site module

<!-- site: lib/my_site/billboard.ex -->
```elixir
defmodule MySite.Billboard do
  @moduledoc """
  The site's pages, as billboard builds them: the sections the
  palette offers, the surfaces they're drawn on, and the pages the
  editor lists. Billboard's getting started guide explains each answer.
  """
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
    # The palette, in order. Reviews and News draw rows the site reads
    # through a `data:` module; add them once it has one.
    components: [
      Billboard.Components.Hero,
      Billboard.Components.Band,
      Billboard.Components.Points,
      Billboard.Components.TextMedia,
      Billboard.Components.Details,
      Billboard.Components.Columns,
      Billboard.Components.Shared
    ],
    # The first is the page's own. assets/css/billboard-tokens.css draws both.
    surfaces: [%{name: "paper", label: "Paper"}, %{name: "band", label: "Band"}],
    offered: [page: ["paper"], stand_out: ["band"], card: []],
    starter: Pages.Starter,
    layout: MySiteWeb.Layouts

  pages do
    page "/", "Home", kind: :free
  end
end
```

`config :billboard, site: MySite.Billboard`, in `config/config.exs`,
names it. Its answers:

- `otp_app` is the site's application.
- `repo` is its AshPostgres repo, which keeps the pages.
- `pubsub` is its `Phoenix.PubSub` server, on which open pages and
  editors hear of each publish.
- `domain` is the Ash domain for the pages, `MySite.Pages`, which does
  `use Billboard.Domain`.
- `resources` names the four modules billboard writes the page record,
  its versions, its sections, and their content into.
- `components` is the whole palette, in the order the editor offers it.
  The hero is first, though the palette never offers it: every page has
  exactly one, at the top. Two columns holds two sections side by side,
  and Shared places a section from the shared library. Reviews and News
  aren't listed, since each draws rows the site reads through a `data:`
  module, and without one they draw nothing.
- `surfaces` names the grounds a section is drawn on, and `offered` says
  which each kind of section may take. The first surface is the page's
  own. A `:page` section sits on the page's ground, and a `:stand_out`
  one breaks from it, so each kind needs a surface. Cards are offered
  none here, so a card is drawn on its section's. See
  [Theming](theming.md).
- `starter` says what a page shows before its first publish.
- `layout` is the site's chrome round every page.
- `pages` lists the pages the editor knows, by route pattern.

The installer leaves out the answers a site gives once it needs them:
`actions`, the site's own kinds of button ([Parts reference](parts.md));
`context`, `data`, and `kinds`, for pages about something and sections
that draw rows ([Page kinds and bound sections](page-kinds-and-bound-sections.md));
`palette`, the palette's words ([Writing a component](writing-a-component.md));
`options`, the settings the site narrows ([Theming](theming.md));
`rules`, its own page rules ([Why the rules exist](why-the-rules-exist.md));
and `reserved_ids`, `page_events`, and `example_path` (`Billboard.Site`).

### The resources

Billboard writes its resources into five modules of the site's: the
domain, `MySite.Pages`, and four resources in it, each a line long:

<!-- site: lib/my_site/pages/page.ex -->
```elixir
defmodule MySite.Pages.Page do
  @moduledoc """
  A page the builder knows, by its route pattern. Billboard writes the resource.
  """
  use Billboard.Page, site: MySite.Billboard
end
```

`MySite.Pages.Version` does `use Billboard.Version`, for a page's live
version and its draft; `MySite.Pages.Section` does `use Billboard.Section`;
and `MySite.Pages.Content` does `use Billboard.Content`, the union of
the site's components that a section holds. The domain does
`use Billboard.Domain`, and the installer lists it in the app's
`ash_domains`. `mix ash.codegen` wrote their tables: `billboard_pages`,
`billboard_versions`, and `billboard_sections`.

### The starter

<!-- site: lib/my_site/pages/starter.ex -->
```elixir
defmodule MySite.Pages.Starter do
  @moduledoc """
  What each page shows before its first publish: a hero, whose words
  the editor marks as filler until they're written over. The shared
  library starts empty.
  """
  @behaviour Billboard.Starter

  alias MySite.Pages.{Section, Version}

  @impl true
  def version(nil), do: %Version{status: :starter, sections: []}

  def version(_pattern) do
    hero = Billboard.Component.build!(:hero, Billboard.SiteOptions.placeholder(:hero))

    %Version{
      status: :starter,
      sections: [
        %Section{
          key: "hero",
          position: 0,
          children: [],
          content: %Ash.Union{type: :hero, value: hero}
        }
      ]
    }
  end
end
```

Every page starts with a hero, since the palette never offers one: a
page that started without it could never get one. `nil` is the shared
library, which has no hero.

### The layout

The installer adds `page/1` to `MySiteWeb.Layouts`:

<!-- site: lib/my_site_web/components/layouts.ex -->
```elixir
  attr :flash, :map, required: true
  attr :site, :map, default: %{}
  attr :current_path, :string, default: nil
  attr :editing, :boolean, default: false
  slot :hero, required: true
  slot :inner_block, required: true

  @impl Billboard.Layout
  def page(assigns) do
    ~H"""
    <header class="bb-wrap flex items-center justify-between py-6">
      <a href="/" class="bb-type-label text-bb-ink">My site</a>
    </header>
    <div class="bb-surface-band">{render_slot(@hero)}</div>
    <main>{render_slot(@inner_block)}</main>
    <footer class="bb-wrap bb-type-small py-12 text-bb-ink-soft">
      My site
    </footer>
    <.flash_group :if={!@editing} flash={@flash} />
    """
  end
```

The visitor's page and the editor both draw through it, so the editor
shows each page in the site's own header and footer. The hero is drawn
on the band, the stand-out surface. `editing` is true in the editor,
which draws its own bar and messages, so the layout draws no messages
then, and nothing else that would sit over the page. `Billboard.Layout`
says what each assign holds.

### The visitor page

`--home` writes `MySiteWeb.BillboardPageLive`, in
`lib/my_site_web/billboard_page_live.ex`, which draws any of the site's
pages for visitors. It finds the page by its route's pattern, draws the
live version through `Billboard.Sections.page/1`, and listens for each
publish:

<!-- site: lib/my_site_web/billboard_page_live.ex -->
```elixir
  # Every publish refreshes billboard's cache, and every open page hears
  # it, so a page reads its data again only when its own version has
  # changed, and takes the library afresh only when the library has.
  @impl true
  def handle_info({:pages_updated, _node, snapshot}, socket) do
    pattern = socket.assigns.pattern
    version = Billboard.Snapshot.page(snapshot, pattern) || Pages.page_for(pattern)
    library = Billboard.Snapshot.page(snapshot, nil) || Pages.page_for(nil)

    socket =
      if same_version?(socket.assigns.library, library),
        do: socket,
        else: assign(socket, :library, library)

    socket =
      if same_version?(socket.assigns.version, version),
        do: socket,
        else: load(socket, version)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Billboard.Sections.page
      version={@version}
      data={@data}
      library={@library}
      site={@site}
      flash={@flash}
      current_path={@current_path}
    />
    """
  end
```

It routes `/` there, in place of phx.new's `get "/"`:

<!-- site: lib/my_site_web/router.ex -->
```elixir
    live_session :current_user,
      on_mount: [{MySiteWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/", BillboardPageLive
    end
```

The route is inside `live_session :current_user` because phx.gen.auth's
root layout reads `@current_scope`, which a LiveView has only in a
session whose `on_mount` assigns it.

### The editor's route

<!-- site: lib/my_site_web/router.ex -->
```elixir
    live_session :require_authenticated_user,
      on_mount: [{MySiteWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      billboard_editor "/admin/pages", back: {"Home", "/"}
    end
```

`billboard_editor` comes from `import Billboard.Editor.Router`, which the
installer adds to the router. The editor acts as `@current_scope.user`,
the user the session signed in. `back:` is the bar's way out: its words,
and where it goes. `Billboard.Editor.path/3` gives the editor's address
for any page, and for a section to open on it, so the rest of the site
can link there.

The installer mounts the editor only in a `live_session` that requires
signing in, and never in `:current_user`, which lets everyone in. By
default, that's a session whose `on_mount` runs `:require_authenticated`,
as phx.gen.auth's does. A session `--live-session` names is mounted in
when its `on_mount` names a `require_…` hook, such as
`{MySiteWeb.UserAuth, :require_admin}`, and otherwise trusted, with a
warning that the installer couldn't confirm it requires signing in. The
installer reads only the hook's name, so make sure the session admits
only the people who may edit.

### Before you deploy

The editor checks no permission of its own: every signed-in user can
edit and publish every page. phx.gen.auth's `/users/register` lets
anyone sign up, so anyone could. Before the site goes live, close
registration, or mount the editor in a `live_session` only your admins
can join (`--live-session`), as the install notice says.

### The cache

<!-- site: lib/my_site/application.ex -->
```elixir
      {Phoenix.PubSub, name: MySite.PubSub},
      Billboard.Cache,
```

`Billboard.Cache` holds what each page shows visitors, so a visit reads
no database. Each publish refreshes it and broadcasts the new pages on
the site's PubSub, which is why it starts after PubSub and the repo, and
before the endpoint.

### The uploads

Photographs uploaded in the editor are kept on disk and served under
`/uploads`, by a plug the installer puts before the endpoint's
`Plug.Static`:

<!-- site: lib/my_site_web/endpoint.ex -->
```elixir
  # Photographs uploaded in billboard's editor, from config :billboard, :uploads_dir.
  plug Billboard.Plugs.UploadsStatic
```

The directory is `config :billboard, :uploads_dir`: the site's
`priv/uploads` in development, set beside the site module,

<!-- site: config/config.exs -->
```elixir
config :billboard, site: MySite.Billboard, uploads_dir: Path.expand("../priv/uploads", __DIR__)
```

`tmp/test-uploads` in tests, and, in production, `UPLOADS_DIR`:

<!-- site: config/runtime.exs -->
```elixir
  config :billboard,
    uploads_dir:
      System.get_env("UPLOADS_DIR") ||
        raise(
          "environment variable UPLOADS_DIR is missing. Set it to a directory on a " <>
            "volume that outlives a deploy: billboard keeps uploaded photographs there."
        )
```

Point it at a volume that outlives a deploy, since files written inside
a release are lost with it. `/priv/uploads/` is in `.gitignore`.

### The assets

The installer writes `assets/css/billboard-tokens.css`, the site's
values for billboard's colours, type, and space, and imports it, then
billboard's theme and the editor's styles, after Tailwind:

<!-- site: assets/css/app.css -->
```css
@import "tailwindcss" source(none);
@import "./billboard-tokens.css";
@import "../vendor/billboard/assets/css/theme.css";
@import "../vendor/billboard/assets/css/editor.css";
```

It tells Tailwind which of billboard's files to read, after the site's
own `@source` lines:

<!-- site: assets/css/app.css -->
```css
@source "../vendor/billboard/lib/billboard/sections";
@source "../vendor/billboard/lib/billboard/sections.ex";
@source "../vendor/billboard/lib/billboard/editor_live.ex";
@source "../vendor/billboard/lib/billboard/editor_live";
@source "../vendor/billboard/lib/billboard/editor";
```

Those are where billboard draws classes: its sections, the page, and
the editor. Tailwind reads only those paths, never all of billboard,
since the words in its other code and its docs would build utilities no
page uses.

In `assets/js/app.js`, it imports the editor's hooks after the site's
own colocated ones,

<!-- site: assets/js/app.js -->
```javascript
import {hooks as colocatedHooks} from "phoenix-colocated/my_site"
import {hooks as billboardHooks} from "phoenix-colocated/billboard"
import {EditCanvas, InlineWords} from "../vendor/billboard/assets/js/billboard.js"
```

and hands them to the LiveSocket:

<!-- site: assets/js/app.js -->
```javascript
  hooks: {...colocatedHooks, ...billboardHooks, EditCanvas, InlineWords},
```

The paths go through `assets/vendor/billboard`, a link that
`mix billboard.assets` makes to billboard as Mix found it: `deps/billboard`
for the git dependency, or the checkout `BILLBOARD_PATH` names. The link
is relative, so one path works either way, wherever the site's checkout
sits. The installer runs it in the asset aliases, and before the
development server:

<!-- site: mix.exs -->
```elixir
      "assets.build": ["compile", "billboard.assets", "tailwind my_site", "esbuild my_site"],
      "assets.deploy": [
        "billboard.assets",
        "tailwind my_site --minify",
        "esbuild my_site --minify",
        "phx.digest"
      ],
      # In development, link billboard afresh before the Tailwind watcher
      # reads it, so a switch between a local checkout and the git
      # dependency never leaves the link pointing at the one no longer in use.
      "phx.server":
        if(Mix.env() == :dev, do: ["billboard.assets", "phx.server"], else: ["phx.server"]),
```

The development server relinks it first because Tailwind's watcher reads
through the link from then on, and a switch to or from `BILLBOARD_PATH`
would otherwise leave it pointing at the billboard no longer in use.
`/assets/vendor/billboard` is in `.gitignore`, since the link points
where Mix found billboard on this machine.

### The dark theme

phx.new's layout switches between a light and a dark theme, and paints
the page dark in the dark one. So the tokens file gives paper, the
page's own surface, light words on it: under `[data-theme=dark]`, for
the dark theme chosen, and under `prefers-color-scheme: dark`, for a
page that follows the system's. The two blocks are alike, and a token
the site sets in paper must be set in both of them too, or it keeps its
light value on the dark page. A site with one theme can delete both
blocks.

## Your first page

Start the site with `mix phx.server`, and open
`http://localhost:4000/users/register`. phx.gen.auth signs you in by an
emailed link: register with an email address, then open the email it
sends at `http://localhost:4000/dev/mailbox`, where development keeps
it. Follow its link, and confirm.

Open `/admin/pages`. The home page is its starter, a hero whose heading
is "Your heading": filler until you write over it. Click the heading.
The hero opens, and its issues say it hasn't been written yet. Type a
new heading, and pause: the bar says your changes aren't on the site
yet. Publish, and open `/`, which shows what you published. A visitor's
open page redraws when the next publish lands, with no reload.

Billboard's cache holds what visitors see in memory, outside the
database's test sandbox, so a test that publishes leaves its page in the
cache for the tests after it. Such a test runs `async: false`, takes
`Billboard.Cache.snapshot/0` in its setup, and hands it back to
`Billboard.Cache.put/1` in an `on_exit`.

## More pages

Each page the editor knows is a line of `pages`, and a route:

<!-- sketch -->
```elixir
pages do
  page "/", "Home", kind: :free
  page "/about", "About", kind: :free
end

live "/about", BillboardPageLive
```

The route goes beside the home page's, in `live_session :current_user`.
A page's pattern is its route's: `BillboardPageLive` draws the page whose
pattern is the route that matched, and raises, naming the fix, for a
route with no page. A route that takes parameters, such as
`/items/:slug`, draws data of its own, so it needs a LiveView of its own
([Page kinds and bound sections](page-kinds-and-bound-sections.md)).

The editor's page picker lists the pages in the order `pages` gives
them. A site that writes no `library` line gets
`library "Shared sections"` after its pages: the shared library, which
holds the sections several pages show.

## Working on billboard too

`BILLBOARD_PATH=../billboard` builds the site against a checkout of
billboard beside it, for working on both at once. Since a build made so
mustn't be deployed, make `mix precommit` refuse it:

<!-- sketch -->
```elixir
defp aliases do
  [
    # The site's other aliases, and then:
    precommit: [
      &refuse_billboard_path/1,
      "compile --warnings-as-errors",
      "deps.unlock --unused",
      "format",
      "test"
    ]
  ]
end
```

where `refuse_billboard_path/1` is a private function of `mix.exs` that
calls `Mix.raise/1`, saying to unset `BILLBOARD_PATH`, when it's set.
Billboard's checks of a component or a site report through compile
warnings, so `precommit` compiles with `--warnings-as-errors`, as
phx.new's does.

## Next

[Writing a component](writing-a-component.md) builds a section of the
site's own, and [Theming](theming.md) makes the pages look like the
site's.

Billboard ships `usage-rules.md`, which gives a coding agent the rules
these guides teach. With `{:usage_rules, "~> 1.2", only: :dev}` among
the site's dependencies, add billboard to its `usage_rules` config, as
`usage_rules: [:billboard, "billboard:all"]`, and run
`mix usage_rules.sync`.
