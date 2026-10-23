# Billboard

A page builder for Phoenix sites, built on Ash. A site's sections are
components, Ash embedded resources declared with `use Billboard.Component`,
and the site describes itself through one module that implements
`Billboard.Site`:

```elixir
config :billboard, site: MySite.Billboard
```
