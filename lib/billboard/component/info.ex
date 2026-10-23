defmodule Billboard.Component.Info do
  @moduledoc """
  Reads a component's `component` section. Every option has a
  `component_<option>/1`, which returns `{:ok, value}` or `:error`, and a
  `component_<option>!/1`, which returns the value or raises. Options
  left out return their defaults.

  `parts/1` lists the component's `part` and `parts` entries.
  """
  use Spark.InfoGenerator, extension: Billboard.Component.Dsl, sections: [:component]

  @doc "The component's parts (`Billboard.Component.Part` and `Billboard.Component.Parts`), in the order written."
  @spec parts(module() | map()) :: [Billboard.Component.Part.t() | Billboard.Component.Parts.t()]
  def parts(component), do: component(component)

  @doc "Whether `module` is a billboard component."
  @spec component?(module()) :: boolean()
  def component?(module) when is_atom(module) do
    Spark.Dsl.is?(module, Ash.Resource) and Billboard.Component.Dsl in Spark.extensions(module)
  end
end
