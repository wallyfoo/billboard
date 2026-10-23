defmodule Billboard.Resource do
  @moduledoc """
  Which kind of billboard resource a module is. `use Billboard.Page`,
  `Billboard.Version`, and `Billboard.Section` each mark the resource
  they write.
  """

  @doc "`:page`, `:version`, or `:section` for a billboard resource, and `nil` for any other module."
  @spec kind(module()) :: :page | :version | :section | nil
  def kind(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and Spark.Dsl.is?(module, Ash.Resource),
      do: Spark.Dsl.Extension.get_persisted(module, :billboard_resource)
  end
end
