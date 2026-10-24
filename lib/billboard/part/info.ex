defmodule Billboard.Part.Info do
  @moduledoc """
  Reads a site's part (`Billboard.Part`): its editor entries, in the
  shape a component's are read in, and its blank, as form params.
  """
  use Spark.InfoGenerator, extension: Billboard.Part.Dsl, sections: [:part, :editor]

  @doc "Whether `module` is a site's part, one that does `use Billboard.Part`."
  @spec part?(term()) :: boolean()
  def part?(module) when is_atom(module) do
    # A part is named by a module that may not be loaded yet.
    Code.ensure_loaded?(module) and Spark.Dsl.is?(module, Ash.Resource) and
      Billboard.Part.Dsl in Spark.extensions(module)
  end

  def part?(_other), do: false

  @doc "The part's editor fields, in the shape `Billboard.Component.Info.editor_fields/1` gives."
  @spec editor_fields(module()) :: keyword(keyword())
  def editor_fields(part), do: part |> editor() |> Billboard.Component.Info.specs()

  @doc "What a new item holds, as form params: string keys, all the way down."
  @spec blank(module()) :: map()
  def blank(part), do: part |> part_blank!() |> stringify()

  defp stringify(%{} = map) when not is_struct(map),
    do: Map.new(map, fn {key, value} -> {to_string(key), stringify(value)} end)

  defp stringify(list) when is_list(list), do: Enum.map(list, &stringify/1)
  defp stringify(value), do: value
end
