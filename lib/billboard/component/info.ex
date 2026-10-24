defmodule Billboard.Component.Info do
  @moduledoc """
  Reads a component's `component` and `editor` sections. Every option
  has a `component_<option>/1`, which returns `{:ok, value}` or `:error`,
  and a `component_<option>!/1`, which returns the value or raises.
  Options left out return their defaults.

  `parts/1` lists the component's `part` and `parts` entries, and
  `editor_fields/1` its `editor` section's.
  """
  use Spark.InfoGenerator, extension: Billboard.Component.Dsl, sections: [:component, :editor]

  @doc "The component's parts (`Billboard.Component.Part` and `Billboard.Component.Parts`), in the order written."
  @spec parts(module() | map()) :: [Billboard.Component.Part.t() | Billboard.Component.Parts.t()]
  def parts(component), do: component(component)

  @doc """
  The component's editor fields, in the order written, in the shape the
  editor reads: `{name, spec}`, where `spec` holds the entry's options
  that were given, `as` always among them, sorted by name. A `part` with
  `except` is `{part, except: fields}`. A component with no `editor`
  section has none.
  """
  @spec editor_fields(module() | map()) :: keyword(keyword())
  def editor_fields(component), do: component |> editor() |> specs()

  @doc false
  # Editor entries in the editor's shape, from any module with an
  # `editor` section: a component's or a site part's.
  @spec specs([struct()]) :: keyword(keyword())
  def specs(entries), do: for(entry <- entries, do: {entry.name, spec(entry)})

  defp spec(entry) do
    entry
    |> Map.from_struct()
    |> Map.drop([:name, :__identifier__, :__spark_metadata__])
    |> fold_except()
    |> Enum.reject(fn {_option, value} -> value in [nil, false, []] end)
    |> Enum.sort()
  end

  # `part: :detail, except: [...]` reads as one part with fields left
  # out, which is how the editor looks a part's fields up.
  defp fold_except(%{part: part, except: [_ | _] = except} = spec),
    do: %{Map.delete(spec, :except) | part: {part, except: except}}

  defp fold_except(spec), do: Map.delete(spec, :except)

  @doc "Whether `module` is a billboard component."
  @spec component?(module()) :: boolean()
  def component?(module) when is_atom(module) do
    Spark.Dsl.is?(module, Ash.Resource) and Billboard.Component.Dsl in Spark.extensions(module)
  end
end
