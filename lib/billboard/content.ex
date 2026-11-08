defmodule Billboard.Content do
  @moduledoc """
  What a section holds: one of the site's components, tagged by its key.
  Stored as `{"type": key, "value": fields}`; build one with
  `%Ash.Union{type: :hero, value: %{...}}`.

      defmodule MySite.Pages.Content do
        use Billboard.Content, site: MySite.Billboard
      end

  The union's types are the site's `components:`, in that order, each
  tagged by its `component` attribute (`tag: :component, tag_value:
  key`), which `use Billboard.Component` adds. So an edit that names only
  some fields updates the stored value instead of replacing it
  (`Billboard.Component`, "Every component is tagged").

  A stored section whose key the site no longer lists, as when a site
  takes a component of its own out of `components:`, reads as
  `%Ash.Union{type: :retired, value: %Billboard.Content.Retired{}}`,
  holding its key and fields as they're stored, and is written back as
  it was, so `:retired` is the union's own, and no component may take it
  (`Billboard.Content.Retired`, and the page kinds guide's "Retiring a
  component").

  It's built as the module compiles, from the site's answers and each
  component's key. It recompiles when the site module changes, or when a
  component's key or fields do, but not for every change to a component,
  such as its label or hint.
  """

  @doc false
  defmacro __using__(opts) do
    Billboard.Resource.only!(opts, [:site], "Content")
    site = Billboard.Resource.site!(opts, __CALLER__, :content)

    types =
      for component <- site.components do
        key = key!(component, site.module)
        {key, [type: component, tag: :component, tag_value: key]}
      end

    known = for {key, _config} <- types, do: Atom.to_string(key)
    types = types ++ [retired: [type: Billboard.Content.Retired]]

    quote do
      require unquote(site.module)
      unquote_splicing(Enum.map(site.components, &quote(do: require(unquote(&1)))))

      use Ash.Type.NewType,
        subtype_of: :union,
        constraints: unquote(Macro.escape(types: types))

      @doc false
      def billboard_site, do: unquote(site.module)

      # A stored key the site no longer lists reads as a retired section,
      # rather than failing the whole read, and is written back under the
      # key it came with.
      @impl Ash.Type
      def cast_stored(%{"type" => type, "value" => fields} = stored, constraints)
          when is_binary(type) and is_map(fields) do
        if type in unquote(known),
          do: super(stored, constraints),
          else: {:ok, Billboard.Content.retired(type, fields)}
      end

      def cast_stored(stored, constraints), do: super(stored, constraints)

      @impl Ash.Type
      def dump_to_native(%Ash.Union{type: :retired, value: retired}, _constraints),
        do: Billboard.Content.dump_retired(retired)

      def dump_to_native(value, constraints), do: super(value, constraints)

      @impl Ash.Type
      def dump_to_embedded(%Ash.Union{type: :retired, value: retired}, _constraints),
        do: Billboard.Content.dump_retired(retired)

      def dump_to_embedded(value, constraints), do: super(value, constraints)
    end
  end

  @doc false
  def retired(type, fields) do
    %Ash.Union{
      type: :retired,
      value: %Billboard.Content.Retired{component: type, fields: Map.delete(fields, "component")}
    }
  end

  # The tag goes back in, as every component's stored fields hold it.
  @doc false
  def dump_retired(%Billboard.Content.Retired{component: component, fields: fields}),
    do: {:ok, %{"type" => component, "value" => Map.put(fields, "component", component)}}

  def dump_retired(_other), do: :error

  # A module that isn't a component would fail in `component_key!/1`
  # before the site's verifier could say why, so this says what the
  # verifier would.
  defp key!(component, site) do
    Code.ensure_compiled(component)

    if Billboard.Component.Info.component?(component) do
      case Billboard.Component.Info.component_key!(component) do
        :retired ->
          raise ArgumentError,
                "#{inspect(component)}, in #{inspect(site)}'s `components:`, has the key " <>
                  ":retired, which the content union keeps for sections of components the " <>
                  "site no longer has (Billboard.Content.Retired). Give it another key."

        key ->
          key
      end
    else
      raise ArgumentError,
            "#{inspect(site)} lists #{inspect(component)} in `components:`, which isn't a " <>
              "billboard component. Add `use Billboard.Component` to it, or take it out of " <>
              "`components:`."
    end
  end
end
