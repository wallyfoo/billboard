# Changelog

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
