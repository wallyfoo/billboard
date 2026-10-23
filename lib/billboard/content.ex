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

    quote do
      require unquote(site.module)
      unquote_splicing(Enum.map(site.components, &quote(do: require(unquote(&1)))))

      use Ash.Type.NewType,
        subtype_of: :union,
        constraints: unquote(Macro.escape(types: types))

      @doc false
      def billboard_site, do: unquote(site.module)
    end
  end

  # A module that isn't a component would fail in `component_key!/1`
  # before the site's verifier could say why, so this says what the
  # verifier would.
  defp key!(component, site) do
    Code.ensure_compiled(component)

    if Billboard.Component.Info.component?(component) do
      Billboard.Component.Info.component_key!(component)
    else
      raise ArgumentError,
            "#{inspect(site)} lists #{inspect(component)} in `components:`, which isn't a " <>
              "billboard component. Add `use Billboard.Component` to it, or take it out of " <>
              "`components:`."
    end
  end
end
