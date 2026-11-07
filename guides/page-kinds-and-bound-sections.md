# Page kinds and bound sections

This guide covers what changes from one page to another: the kinds of
page a site has and the components each may hold, the data a section
reads from the site's own resources, the context that says what a page
is about, and replacing a stock component with one of the site's own.
Its example is a Fees section, which shows the fees from one source on
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
