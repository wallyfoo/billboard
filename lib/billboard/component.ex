defmodule Billboard.Component do
  @moduledoc """
  A section type: an Ash embedded resource whose `component` section says
  what the page builder knows about it.

      defmodule MySite.Banner do
        use Billboard.Component

        component do
          key :banner
          label "Banner"
          hint "One idea, set apart."
          category :band
          kinds [:free]
          max 2
          mirror? true
          surface_kind :stand_out
          placeholder %{heading: "Your banner"}
        end

        attributes do
          attribute :heading, :string, public?: true
        end
      end

  `use Billboard.Component` takes `use Ash.Resource`'s options. It sets
  `data_layer: :embedded`, and adds `Billboard.Component.Dsl` to any
  `extensions:` given.

  ## Options

    * `key` (required) is the union tag, and the type name stored in
      content. It can't change once content is stored under it.
    * `label` (required) is the palette's name for it.
    * `hint` (required) is the palette's one line about it.
    * `category` (required) is its palette group.
    * `kinds` is the page kinds that may use it, or `:all` (the default).
    * `max` is how many a page may hold, or `nil` (the default) for any
      number.
    * `column?` is whether it fits in a column. The default is `false`.
    * `mirror?` is whether it has image-left and image-right variants.
      The default is `false`.
    * `surface_kind` is its kind in `Billboard.Surfaces`, which says the
      surfaces it may take. The default is `:page`.
    * `surface_from` is where it takes its surface from when it doesn't
      choose one: `nil` (the default) for its own or its parent's,
      `:library` for a library section's, or `:layout` for the layout's.
    * `placeholder` is what a new section starts with in the editor, by
      attribute. The default is `%{}`.

  `Billboard.Component.Info` reads them.

  ## What the extension adds

    * **The tag**, the `component` attribute:
      `attribute :component, :atom, allow_nil?: false, default: key, public?: true, constraints: [one_of: [key]]`.
      Leave it out; a component that writes its own must make it
      `one_of: [key]`.
    * **The actions**, `defaults [:read, :destroy, create: :*, update: :*]`,
      unless the component writes its own `defaults`. An action the
      component writes by one of those names replaces that default, and
      the others are still added. Create and update accept every public
      attribute, the tag included.

  ## Checks

  A module with no `component` section doesn't compile.

  The rest run once the module has compiled. As with every Spark verifier,
  a failure is printed as a compile warning naming the fix, not raised,
  so `mix compile --warnings-as-errors` stops on it.

    * A `component` attribute the component writes must be
      `one_of: [key]`.
    * Every placeholder key must name an attribute.

  ## Every component is tagged

  Without a tag, Ash treats any map of params as a whole new component:
  whatever the params leave out falls back to its default, so a save
  that names only the heading wipes the lede and resets the variant. With
  `tag: :component, tag_value: key` on the union type, and the tag
  attribute on the component, Ash updates the stored component with the
  params instead. The editor can then save one field, push a variant, or
  set a photograph without sending every other field. Storage stays
  `:type_and_value`; `:map_with_tag` isn't needed. The union's form sends
  `_union_type` for you, and because every type is tagged, a save without
  it still finds the component from the section.
  """

  @doc false
  defmacro __using__(opts) do
    {extensions, opts} = Keyword.pop(opts, :extensions, [])

    quote do
      use Ash.Resource,
          unquote(
            Keyword.merge(
              [data_layer: :embedded, extensions: [Billboard.Component.Dsl | extensions]],
              opts
            )
          )
    end
  end
end
