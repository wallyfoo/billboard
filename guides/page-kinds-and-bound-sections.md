# Page kinds and bound sections

This guide covers what changes from one page to another: the kinds of
page a site has and the components each may hold, the data a section
reads from the site's own resources, the context that says what a page
is about, replacing a stock component with one of the site's own, and
writing a page's sections from code, as a site's seeds do. Its example is a Fees section, which shows the fees from one source on
the fees page and on each service's page, limited to that service.

## Page kinds

Each page in `pages` has a `kind`, an atom of the site's own choosing.
A component's `kinds` lists the kinds of page it may go on, and the
stock components go on every kind (`:all`, the default). `kinds:` in
`use Billboard.Site` narrows a component, stock or the site's, by its
key, so a site needn't write its own component to keep one off a page.

A page with `fixed:` holds exactly the sections it lists, in that
order: its editor changes what they say, but adds, moves, or removes
none. The library, where shared sections are kept, is the page with no
pattern, and its kind is `:library`.

<!-- sketch -->
```elixir
use Billboard.Site,
  # The site's other answers, and then:
  kinds: [
    hero: [:free, :service, :fixed],
    fees: [:free, :service]
  ]

pages do
  page "/", "Home", kind: :free
  page "/fees", "Fees", kind: :free
  page "/services/:slug", "A service", kind: :service
  page "/terms", "Terms", kind: :fixed, fixed: [:hero, :text]
end
```

Here a Fees section may go on the home page, the fees page, and every
service's page, but not on the terms page or in the library.

## Data a section draws

Most sections draw only what the editor typed. A section that shows
the site's own records, such as its fees, reviews, or news, reads them
through the module the site names as `data:`, which follows
`Billboard.Data`:

<!-- from: guides/examples/lib/my_site/pages/data.ex -->
```elixir
defmodule MySite.Pages.Data do
  @moduledoc """
  What the site's pages read for the sections that draw rows: the fees,
  read once for every Fees section on a page.
  """
  @behaviour Billboard.Data

  @impl true
  def fetch(%MySite.Sections.Fees{}, _context, loaded),
    do: Billboard.Data.once(loaded, :fees, &MySite.Fees.list/0)

  def fetch(_content, _context, _loaded), do: :none
end
```

`fetch/3` is given a section's content, the page's context, and what's
been read for the page so far. It's called for every section, so it
ends with a catch-all `:none`; any answer other than `{:ok, value,
loaded}` or `:none` raises an `ArgumentError` naming the section.

`Billboard.Data.once/3` reads a thing once a page, however many
sections ask for it: two Fees sections on one page read the fees once.
`Billboard.Data.cached/3` gives the shared read back for the section to
shape, as `Billboard.Data`'s news example does.

The stock Reviews and News sections read their rows this way, and their
renderers document the fields each row has:
[Reviews](https://github.com/wallyfoo/billboard/blob/v0.5.0/lib/billboard/sections/reviews.ex)
and [News](https://github.com/wallyfoo/billboard/blob/v0.5.0/lib/billboard/sections/news.ex).

## The component that draws it

<!-- from: guides/examples/lib/my_site/sections/fees.ex#component -->
```elixir
component do
  key :fees
  label "Fees"
  hint "What each service costs."
  category :data
  renderer MySiteWeb.Sections.Fees
  context [:scope]
  filler? false
  placeholder %{title: "Fees"}
end

editor do
  words :title, label: "Title", limit: 60
  field :this_service_only, as: :toggle, label: "Only this page's service"
end

attributes do
  attribute :title, :string, public?: true, constraints: [max_length: 120]
  attribute :this_service_only, :boolean, allow_nil?: false, default: false, public?: true
end
```

`context` declares what of the page's context the renderer reads, here
its `:scope`, the service the page is about. The toggle keeps the
section to that service's fees, and on a page about no service it shows
none.

<!-- from: guides/examples/lib/my_site_web/sections/fees.ex#render -->
```elixir
def render(assigns) do
  assigns = assign(assigns, fees: fees(assigns.content, assigns.section, assigns.ctx))

  ~H"""
  <section
    :if={@fees != []}
    id={@anchor}
    data-surface={@ctx.surface}
    class={Parts.section_class(@ctx)}
  >
    <h2 class="bb-heading bb-type-heading text-bb-heading">
      {Words.text(@ctx, "title", @content.title)}
    </h2>
    <ul class="bb-measure mt-8">
      <li :for={fee <- @fees} class="bb-rule-top flex justify-between gap-4 py-4">
        <span class="bb-type-body text-bb-ink">{fee.title}</span>
        <span class="bb-type-subheading text-bb-subheading">{fee.price}</span>
      </li>
    </ul>
  </section>
  """
end

def empty?(content, data, ctx), do: shown(content, data, ctx) == []

def nothing_to_show(_content, _ctx), do: "there are no fees to show."

defp fees(content, section, ctx), do: shown(content, ctx.data[section.key], ctx)

# With `this_service_only` set, only the fees of the page's service.
defp shown(%{this_service_only: false}, fees, _ctx), do: fees || []

defp shown(_content, fees, ctx) do
  scope = get_in(ctx, [:context, :scope])
  Enum.filter(fees || [], &(&1.service == scope))
end
```

`ctx.data[@section.key]` is what `fetch/3` gave this section. A section
with nothing to show draws nothing for a visitor, so `empty?/3` tells
the editor when that's so, and the editor draws a stand-in in its place
that says why, in the words of `nothing_to_show/2`.

## What a page is about

A service's page is about one service: its hero's heading is the
service's name, and its Fees section shows that service's fees. The
site builds each page's context in its LiveViews, and hands it to
`Billboard.Sections.page/1`, where every renderer reads it as
`ctx.context`. `:bindings` and `:scope` are the entries the stock
components read.

The editor needs to know the same things without a visitor's route, so
the site names a module as `context:`, which follows
`Billboard.Context`:

<!-- from: guides/examples/lib/my_site/pages/context.ex -->
```elixir
defmodule MySite.Pages.Context do
  @moduledoc """
  What the site's pages are about: a service's page is about that
  service, whose name stands in for its hero's heading, and whose fees
  a Fees section may show alone.
  """
  @behaviour Billboard.Context

  @services [
    {"Assessments", "assessments"},
    {"Therapy", "therapy"},
    {"Supervision", "supervision"}
  ]

  @impl true
  def bindings,
    do: [
      service: [
        note: "The heading comes from the service.",
        link: {"Open the services", "/admin/services"},
        replaces_words: true
      ]
    ]

  @impl true
  def choice_sets, do: [:services]

  @impl true
  def choices(:services),
    do: %{
      options: @services,
      every: "Every service",
      none_yet: "There are no services yet.",
      gone: "not a service now"
    }

  # The editor draws a service's page about the first service.
  @impl true
  def sample(%{pattern: "/services/:slug"}),
    do: %{bindings: %{service: %{heading: "Assessments"}}, scope: "assessments"}

  def sample(_page), do: %{}

  @impl true
  def path(%{pattern: nil}, _context), do: nil
  def path(%{pattern: "/services/:slug"}, %{scope: scope}), do: "/services/#{scope}"
  def path(%{pattern: "/services/:slug"}, _context), do: nil
  def path(%{pattern: pattern}, _context), do: pattern
end
```

- `bindings/0` lists what a hero may take its heading from. The editor
  says so in the note, and links to where it's changed.
- `choice_sets/0` names the sets of choices `choices/1` gives, and
  `use Billboard.Site` refuses a context that gives one without the
  other. A picker of a set the site doesn't give draws nothing.
- `choices/1` fills a picker: its options, and the words for every
  option, none yet, and an option that's gone.
- `sample/1` is what the editor draws a page with a parameter about,
  and `path/2` is that page's address, for its preview link; the
  library has none.

A hero saved bound to a binding the site no longer lists keeps the
binding. Billboard loads the context module at boot to read stored
sections, so it must keep naming every binding a stored section holds.

## Handing a page its context

The context module tells the editor what a page is about. A visitor's
page is told by the LiveView that draws it, which builds the page's
context, reads the page's data with it, and hands it to the sections.
`mix billboard.install --home` writes `BillboardPageLive`, which does
all three for every page it draws, from the context module's
`sample/1`:

<!-- from: priv/templates/billboard.install/page_live.ex.eex#load -->
```elixir
# What the page is about (`Billboard.Context`): the site's context
# module's `sample/1` for it, which is what the page editor draws it
# about too. A route with no parameters is always about the same
# thing, so the sample is the page's own context. The data its
# sections read, and the sections themselves, are given it.
defp load(socket, version) do
  page = Billboard.Directory.fetch(socket.assigns.pattern)
  context = Billboard.Context.sample(page)

  assign(socket,
    version: version,
    context: context,
    data: Billboard.Resolver.resolve(version, context),
    page_title: page.title || Billboard.Sections.Hero.title(version)
  )
end
```

<!-- from: priv/templates/billboard.install/page_live.ex.eex#render -->
```elixir
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
    ctx={%{context: @context}}
  />
  """
end
```

- `Billboard.Context.sample/1` is the site's `sample/1` for the page,
  or `%{}` for a site that names no context module.
- `Billboard.Resolver.resolve/2` hands the context to the data module's
  `fetch/3`, as its second argument.
- `ctx={%{context: @context}}` is where every renderer reads it, as
  `ctx.context`: a bound hero its `:bindings`, a detail its `:scope`,
  and the Fees section above its `:scope`.

A page whose route has no parameter, such as `/assessments`, is always
about the same thing, so its sample is its context. A context module
with `def sample(%{pattern: "/assessments"}), do: %{scope: "assessments"}`
draws that page about the assessments, for its visitors and in the
editor alike, and its Fees section, with "Only this page's service"
on, shows the assessments' fees.

A page whose route takes a parameter, such as `/services/:slug`, is
about whatever the address names, so it has a LiveView of its own,
which builds the context from its params in place of the sample, as
`%{scope: slug, bindings: %{service: %{heading: service.name}}}`
for the service the slug names. It hands it on in the same two places,
`Billboard.Resolver.resolve(version, context)` and
`ctx={%{context: @context}}`, and draws and listens as
`BillboardPageLive` does.

A `BillboardPageLive` written by billboard 0.5.0 or earlier passes no
context, and the installer never rewrites a file the site has. Until
the site changes it, its pages are drawn about nothing in particular,
which is right only for a site with no context module. To bring it up
to date, make its `load/2` the one above, and add
`ctx={%{context: @context}}` to its `<Billboard.Sections.page>`.

## Replacing a stock component

A site replaces a stock component by listing its own, with the stock
one's key, in the stock one's place in `components:`. Stored sections
keep their content, so the replacement must accept the stock fields,
or the site migrates the sections it has.

A replacement hero draws only what's inside its block. The page keeps
`<section id="page-hero" class="bb-section-pad">`, in the layout's hero
slot, and the editor's marks go round it on every page; the hero's
renderer's `render/1` is given `section`, `content`, `anchor`, and
`ctx`, as any section's is. So it draws no `id={@anchor}`, no
`Parts.section_class/1`, and no `@ctx.surface`, since the layout's
hero slot gives the block its surface; it starts with a `bb-wrap`
element for the page's width; and its component says
`surface_from :layout`, or the editor offers a ground the page never
draws.

`heading` and `lede` are the page's, for a version with no hero, and
the stock renderer draws them whatever the site's hero.
`Billboard.Sections.Hero.title/2` reads any hero's `heading` for the
browser title. If the layout's skip link lands on `#main`, the
replacement keeps a `#main` target.
[The stock hero](https://github.com/wallyfoo/billboard/blob/v0.5.0/lib/billboard/sections/hero.ex)
is the example to start from.

A smaller change may need no replacement at all. A round portrait in
a ring is the hero's photograph tokens, `--bb-hero-photo-ratio: 1` and
`--bb-hero-photo-max`, with `--bb-radius-photo: 50%` and the ring set
on `#page-hero .bb-photo`, as the theming guide's
[Hooks for decoration](theming.md#hooks-for-decoration) shows; the
other hooks, and the layout's hero slot, are often enough for the
rest.

## Pages from code

A page's layout is the editor's to make, but code can write one too,
so that a fresh database starts with a page's approved layout and its
placeholder copy. `Billboard.Pages.put_page/3`, which the site's domain
gives as `MySite.Pages.put_page/3` as well, makes the page at a route
pattern hold exactly the sections it's given, in order, and publishes
them, so visitors see them. A home page with a hero, three points, a
band, and a Text and image section, from the site's own module:

<!-- from: guides/examples/lib/my_site/pages/seeds.ex#home -->
```elixir
def home do
  Billboard.Pages.put_page(
    "/",
    [
      %{
        type: :hero,
        key: "home-hero",
        content: %{
          variant: :media_right,
          eyebrow: "Psychology in the city",
          heading: "Talking helps",
          lede: "Assessments and therapy for adults, in person and online.",
          actions: [
            %{label: "Book a first session", path: "/contact", style: :primary},
            %{label: "How it works", path: "/about", style: :secondary}
          ],
          photo: %{label: "The consulting room"}
        }
      },
      %{
        type: :points,
        key: "home-points",
        anchor: "how-we-work",
        content: %{
          head: %{eyebrow: "How we work", heading: "Three things to know"},
          columns: 3,
          points: [
            %{title: "Unhurried", body: "Fifty minutes, every time."},
            %{title: "Plain words", body: "No jargon in the room or in the report."},
            %{
              title: "Near you",
              body: "Ten minutes from the station.",
              link: %{label: "Find us", path: "/contact", style: :text}
            }
          ]
        }
      },
      %{
        type: :band,
        key: "home-band",
        surface: "band",
        content: %{
          variant: :heading,
          eyebrow: "First sessions",
          heading: "A first talk costs nothing",
          body: "Twenty minutes on the phone, to see whether we suit you.",
          action: %{label: "Ask for a call", path: "/contact", style: :secondary}
        }
      },
      %{
        type: :text_media,
        key: "home-about",
        content: %{
          variant: :media_left,
          head: %{heading: "Who you'll see"},
          body: "Every psychologist here is registered and supervised.",
          photo: %{label: "The team, outside"}
        }
      }
    ],
    authorize?: false
  )
end
```

`priv/repo/seeds.exs` runs it, as `{:ok, _home} = MySite.Pages.Seeds.home()`,
which `mix run priv/repo/seeds.exs` runs, and so do phx.new's
`mix ecto.setup` and `mix ecto.reset`. A seeds file is a script, so the
site keeps the layout in a module under `lib/`, where it's compiled
and can be tested, and the script only calls it.

### Its arguments

`put_page(pattern, sections, opts)`:

- `pattern` is the page's route pattern, as its `page` entry in the
  site's `pages` block names it, such as `"/"` or `"/services/:slug"`,
  or `nil` for the library of shared sections. The page's record is
  found, or made if it has none; a pattern the site has no page for is
  refused, with "there is no such page".
- `sections` is a list of maps, one for each section, in the order the
  page draws them:

  | Key | What it is | Needed |
  | --- | --- | --- |
  | `type` | the component's key, as `:hero`, `:points`, `:band`, `:text_media`, or a site's own, as `:fees` | yes |
  | `content` | a map of the component's fields, its parts as maps too | yes |
  | `surface` | the name of a surface the site offers the component's kind, as `"band"`, or nil for its kind's default ([Theming's Surfaces](theming.md#surfaces)) | no |
  | `anchor` | its DOM id on the page, for in-page links, as `"how-we-work"`: lowercase letters, digits, and hyphens, starting with a letter, and none the site's layout reserves | no |
  | `key` | the string the editor follows it by; one is made if it's left out | no |
  | `children` | a Two columns section's two sections, each a map like these | only for `:columns` |

- `opts` go to each action it runs. Seeds have no signed-in user, and
  every write needs an actor, so they pass `authorize?: false`; code
  with a user passes `actor: user`. `publish: false` leaves the
  sections in the page's draft, for someone to look over in the editor
  and publish, and returns the draft.

It returns `{:ok, version}`, the live version with its sections, or
`{:error, error}`, which says what's wrong.

### Each section's content

`content` is what `Billboard.Component.build/2` takes for the component:
its fields by name, the values the editor would save. A site's own
component has the attributes it declares; the stock components have
these, and a field left out takes the default shown:

| Type | Its fields |
| --- | --- |
| `:hero` | `variant` (`:media_right`, `:media_left`, or `:text_only`), `size` (`:h1`, `:display`, or `:auto`), `bind` (`:none`, or a binding the context module names), `eyebrow`, `heading`, `lede` (Markdown), `actions` (up to three actions), `photo` |
| `:points` | `columns` (3; 2 to 4), `look` (`:rows` or `:cards`), `head`, `points` (one to four points) |
| `:band` | `variant` (`:heading`, `:quote_left`, or `:quote_right`), `eyebrow`, `heading`, `body` (Markdown), `quote`, `action` |
| `:text_media` | `variant` (`:media_right`, `:media_left`, or `:text_only`), `head` (needed), `body` (Markdown), `actions` (up to two), `photo` (needed unless `:text_only`) |
| `:details` | `width` (`:standard` or `:narrow`), `head`, `items` (details, up to twelve) |
| `:reviews` | `head` (headed "What clients say"), `note`, `initial` (6, how many show at first); its rows are the site's data |
| `:news` | `head`, `empty` (the words when there's none), `limit` (2); its rows are the site's data |
| `:columns` | `variant` (`:even`, `:wide_left`, or `:wide_right`); its two sections are its `children` |
| `:shared` | `key`, the key of the library section it places |

A hero's `heading` is needed unless it's bound, and a band's `heading`
or `quote` as its `variant` says. A site that narrows a component's
choices in its options (`Billboard.SiteOptions`), such as Points'
looks, is held to them here too, and a field it makes an offer for,
left out, takes the site's first choice in place of the default shown.

A part is a map of its own fields, as [Parts](parts.md) lists them: a
`head` is `%{eyebrow: ..., heading: ...}`; an action is
`%{label: ..., path: ..., style: ...}`, its `kind` `:link` unless given,
its `style` `:primary`, `:secondary`, or `:text`; a list of parts, such
as Points' `points` or the hero's `actions`, is a list of those maps;
and a photograph is `%{label: ...}`, which draws the placeholder, in
the site's noise colours, with its label on top, until someone uploads
the photograph in the editor. Every check the editor makes holds here
too: a field past its length, a missing heading, or a surface the site
doesn't offer is refused, and nothing is written.

### Running it again

`put_page/3` throws away the page's draft, if it has one, writes a new
draft holding only `sections`, and commits it, which replaces the live
version, all in one transaction. So it can run any number of times,
and each run puts the same page back. That includes over what editors
have published since: a site runs its seeds on a fresh database, or
to start a page over, not on a site whose pages its editors have
changed.

The commit checks the page against the rules, as the editor's Publish
does ([Why the rules exist](why-the-rules-exist.md)): every page but
the library opens with exactly one hero, a fixed page holds exactly
its fixed sections, in order, and the rest. A layout that breaks one
changes nothing, neither the draft nor the live version, and the error
names the rule.

### Other ways to put sections on a page

- A starter (`Billboard.Starter`) is a page's layout in code, drawn
  until the page's first publish, with nothing in the database. Choose
  it for a layout every new site starts with; choose `put_page/3` for
  a layout stored and published, as an editor's would be.
- To add to a page rather than replace it, change its draft as the
  editor does: `MySite.Pages.change_draft/3` runs a function on the
  page's draft, and `MySite.Pages.create_section/2` adds a section to
  it, then `MySite.Pages.commit_page/2` publishes it. `Billboard.Domain`
  lists every function, and its arguments.
