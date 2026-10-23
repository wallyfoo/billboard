defmodule Billboard.Site do
  @moduledoc """
  What billboard asks of the site using it. A site names one module that
  implements this behaviour:

      config :billboard, site: MySite.Billboard

  Step 3 replaces the hand-written module with `use Billboard.Site`,
  which takes the same answers as options.
  """

  @typedoc "A surface's name, its `bb-surface-NAME` class, and the label the editor shows."
  @type surface :: %{name: String.t(), label: String.t()}

  @doc "The site's components, stock and its own, in palette order."
  @callback components() :: [module()]

  @doc "The site's surfaces, in order. The first is the page's own."
  @callback surfaces() :: [surface()]

  @doc "For each kind of section or card, the surfaces it may take, in order. See `Billboard.Surfaces`."
  @callback offered() :: keyword([String.t()])

  @doc "The values the site offers in components' settings, by type and field. See `Billboard.SiteOptions`."
  @callback options() :: keyword(keyword())

  @doc "The site's own page rules, each a `Billboard.Rule`."
  @callback rules() :: [module()]

  @doc "The site's module. Raises when none is configured."
  @spec get!() :: module()
  def get! do
    Application.get_env(:billboard, :site) ||
      raise ArgumentError,
            "billboard doesn't know the site's module. Add " <>
              "`config :billboard, site: MySite.Billboard` to config/config.exs"
  end

  @doc "The site's components."
  @spec components() :: [module()]
  def components, do: get!().components()

  @doc """
  The component whose key is `type`. Raises for one the site doesn't list,
  and for a module in the site's list that isn't a component.
  """
  @spec component!(atom()) :: module()
  def component!(type) when is_atom(type) do
    Enum.find(components(), &(key!(&1) == type)) ||
      raise ArgumentError,
            "the site has no component #{inspect(type)}. Add its module to the site's components/0"
  end

  defp key!(module) do
    if Billboard.Component.Info.component?(module) do
      Billboard.Component.Info.component_key!(module)
    else
      raise ArgumentError,
            "the site's components/0 lists #{inspect(module)}, which isn't a billboard " <>
              "component. Add `use Billboard.Component` to it, or take it out of components/0"
    end
  end
end
