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

  `use Billboard.Component` takes `use Ash.Resource`'s options, but not
  `data_layer:`: it sets `data_layer: :embedded` itself, and raises when
  given another. It adds `Billboard.Component.Dsl` to any `extensions:`
  given, which must be a literal list, such as
  `extensions: [MyApp.Extension]`, since it's joined to billboard's as the
  module is compiled.

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
      surfaces it may take. The default is `:page`. It can't be `:card`,
      which is the kind of a card inside a section, not of a section.
    * `surface_from` is where it takes its surface from when it doesn't
      choose one: `nil` (the default) for its own or its parent's,
      `:library` for a library section's, or `:layout` for the layout's.
    * `placeholder` is what a new section starts with in the editor, by
      attribute. The default is `%{}`. Build a new section from
      `Billboard.SiteOptions.placeholder/1`, which leaves out a value the
      site doesn't offer, so the site's default takes its place.

  ## Parts

  A part is an embedded resource held in an attribute of the component,
  such as a heading or a row of points. Declare them in the `component`
  section, among the options:

      part :head, MySite.Parts.Head
      parts :points, MySite.Parts.Point, min: 1, max: 3

    * `part name, type` holds one part, in
      `attribute name, type, public?: true`. Its options are `allow_nil?`
      (default `true`), `default`, such as
      `default: %MySite.Parts.Head{heading: "What clients say"}`, and
      `description`.
    * `parts name, type` holds a list, in
      `attribute name, {:array, type}, public?: true, allow_nil?: false, default: []`.
      Its options are `min` and `max`, which become the `min_length` and
      `max_length` constraints when given, `allow_nil?` (default `false`),
      and `description`.

  A part named like an attribute the component writes doesn't compile.

  Every part follows two rules, which
  `Billboard.Component.Verifiers.VerifyParts` checks:

    * **Every component and part has a destroy action**:
      `defaults [:read, :destroy, create: :*, update: :*]`. Ash destroys
      the old value when a list item is dropped or an optional part is
      cleared, and raises when there is no primary destroy action.
      Billboard adds a component's; a part writes its own.

    * **A part that sits in a list has `uuid_primary_key :id`.** A list item
      without a key is rebuilt from its params alone, so a list change made
      on the server (`AshPhoenix.Form.add_form/3` or `remove_form/3`, then
      submit) resets every untouched item to its defaults. With a key,
      the item's id rides in its hidden fields, Ash matches it to the stored
      item, and updates it; reordering is sending the ids in the new order.
      A part used only singly, such as a photo, needs no key.

  `Billboard.Component.Info` reads the options and the parts.

  ## What the extension adds

    * **The tag**, the `component` attribute:
      `attribute :component, :atom, allow_nil?: false, default: key, public?: true, constraints: [one_of: [key]]`.
      Leave it out; a component that writes its own must write it
      exactly so.
    * **The actions**, `defaults [:read, :destroy, create: :*, update: :*]`,
      unless the component writes its own `defaults`. An action the
      component writes by one of those names replaces that default, and
      the others are still added. Create and update accept every public
      attribute, the tag and the parts included.
    * **An attribute for each part**, see Parts.
    * **The site's options**, `Billboard.Changes.SiteOptions`, as a
      global change on create and update, after any global changes the
      component writes. A new component takes the site's defaults, and a
      change to a value the site doesn't offer is refused. See
      `Billboard.SiteOptions`.

  ## Checks

  A module with no `component` section doesn't compile.

  A part named like an attribute, or `:component`, doesn't compile, nor
  does a `parts` whose `min` is above its `max`.

  The rest run once the module has compiled. As with every Spark verifier,
  a failure is printed as a compile warning naming the fix, not raised,
  so `mix compile --warnings-as-errors` stops on it.

    * A `component` attribute the component writes must be exactly what
      billboard adds: its type, `allow_nil?`, `default`, `public?`, and
      `one_of: [key]`.
    * It must have a primary read, create, update, and destroy action,
      which matters only when it writes its own `defaults`.
    * Every placeholder key must be one the primary create accepts.
    * `surface_kind` can't be `:card`, since a section can't be drawn on
      a card's kind.
    * Every part must be an Ash resource with a primary destroy action,
      and one in a `parts` list must have an `:id` primary key (see
      Parts).

  ## Every component is tagged

  Without a tag, Ash treats any map of params as a whole new component:
  whatever the params leave out falls back to its default, so a save
  that names only the heading wipes the lede and resets the variant. With
  `tag: :component, tag_value: key` on the union type, and the tag
  attribute on the component, Ash updates the stored component with the
  params instead. The editor can then save one field, push a variant, or
  set a photograph without sending every other field. Storage stays
  `:type_and_value`; `:map_with_tag` isn't needed.

  ## Editing content through a form

  A section's editor form is an AshPhoenix form whose `content` is a
  nested form for the section's component.

    * **The union type is sent for you.** `<.inputs_for field={f[:content]}>`
      renders `_union_type` as a hidden input, so the editor needs no
      input of its own. Because every type is tagged, a save without it
      still finds the component from the section. Untagged, it raises.

    * **Errors sit on the content form.** A failed rule shows on the nested
      field (`c[:heading].errors`), and
      `AshPhoenix.Form.errors(form, for_path: [:content])` lists them.
      `AshPhoenix.Form.submit/2` returns `{:error, form}` and saves nothing.

    * **Pass `params:` to `AshPhoenix.Form.submit/2`** (`nil` to reuse the
      validated params); AshPhoenix warns when it is left out.

  ## Keys the builder reserves

  Three keys mean something to the page engine, whatever component
  holds them: a page opens with one `:hero`, which stays first and can't
  be removed; a `:columns` section holds two sections as its children; and
  a `:shared` section draws the library section its `key` attribute
  names. A site without a `:hero` component has no opener rule.
  """

  @doc false
  defmacro __using__(opts) do
    if Keyword.has_key?(opts, :data_layer) do
      raise ArgumentError,
            "a billboard component is an embedded resource, so `use Billboard.Component` " <>
              "sets `data_layer: :embedded` itself. Take `data_layer:` out."
    end

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

  @doc """
  Builds the component `type` from `attrs`, applying its defaults and
  running its validations, as a save would. Raises `Ash.Error.Invalid`
  when they fail, and `KeyError` for a type the site doesn't list.
  `Ash.create!/1` works on an embedded resource, so no casting by hand is
  needed, and a section can be created with the result
  (`%Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)}`).
  """
  @spec build!(atom(), map()) :: struct()
  def build!(type, attrs) do
    type
    |> Billboard.Catalogue.module!()
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!()
  end

  @doc """
  Like `build!/2`, but returns `{:ok, component}`, or `{:error, error}`
  when the defaults and validations fail.
  """
  @spec build(atom(), map()) :: {:ok, struct()} | {:error, term()}
  def build(type, attrs) do
    type
    |> Billboard.Catalogue.module!()
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end
end
