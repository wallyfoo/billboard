# Billboard

A page builder for Phoenix sites, built on Ash. A site's sections are
components, Ash embedded resources declared with `use Billboard.Component`.
Billboard knows what each one is to the builder: its palette entry, the
surfaces it may be drawn on, the values a site offers in its settings, and
the rules a page keeps.

Billboard is pre-1.0. It grows with the needs of Stylish Strands, its
first site, and its API may change between minor versions until 1.0.

## Installation

Add it as a git dependency, pinned to a tag:

```elixir
def deps do
  [
    {:billboard, git: "https://github.com/wallyfoo/billboard.git", tag: "v0.1.0"}
  ]
end
```

Import its formatter rules in `.formatter.exs`, so `component` sections
format without parentheses:

```elixir
[
  import_deps: [:ash, :billboard],
  # ...
]
```

## The site

The site describes itself through one module that implements
`Billboard.Site`: its components, its surfaces and what each kind of
section is offered, the values it offers in components' settings, and its
own page rules. Name it in `config/config.exs`:

```elixir
config :billboard, site: MySite.Billboard
```

A consumer needs no Ash config from billboard: the Ash config in its
`config/` is for its own tests, and a site's is the site's own.

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
