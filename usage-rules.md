# Rules for working with Billboard

Billboard is a page builder for Phoenix sites on Ash: pages made of
sections, written in place in an editor, published as a whole. Read its
guides (`mix docs` in the dependency, or `deps/billboard/guides/`)
before changing a site's billboard code. Don't guess an API: every
module named here has docs.

## The shape of a site

- One site module, `use Billboard.Site`, holds the site's answers
  (components, surfaces, offers, options, rules, starter, layout, data,
  context, and actions) and its `pages`. It names modules; it never
  calls them, so it compiles against billboard alone.
- Five thin modules, each a single `use`: `Billboard.Page`,
  `Billboard.Version`, `Billboard.Section`, `Billboard.Content`, and
  `Billboard.Domain`, with `site:`. Never add attributes, actions, or
  policies to them: billboard writes the resources.
- A component is two modules: an embedded resource with
  `use Billboard.Component` for its data, and a renderer with
  `use Billboard.Renderer` for its look. See the components sub-rule.
- Styling goes through billboard's tokens and `bb-` utilities. See the
  theme sub-rule.

## Always

- Start a component with `mix billboard.gen.component MySite.Sections.Name`,
  and keep its test, which calls `assert_component_works/2`
  (`Billboard.ComponentCase`).
- Compile with `mix compile --warnings-as-errors`: billboard's checks
  report as compile warnings, and a component that breaks one still
  compiles without it.
- After changing a component's fields, a part's, or the site's
  resources, run `mix ash.codegen` and check it creates nothing for
  content (content is stored as JSON) unless the change was to a table.

## Never

- Never change a component's `key`: it's what stored content is filed
  under.
- Never take away the `component` tag, a list part's `uuid_primary_key
  :id`, or a part's primary destroy action. `guides/why-the-rules-exist.md`
  says why.
- Never call `Billboard.Pages` functions from a renderer: a renderer
  draws what it's given (`@content`, `@ctx`).
- Never style a stock component by editing billboard: use tokens, a
  surface, or a hook class from the site's CSS.
