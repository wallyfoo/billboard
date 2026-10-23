defmodule Billboard.Resource.Kind do
  @moduledoc false
  # `Billboard.Resource.kind/1`, on its own, so that the site's resource
  # verifier, which every site module compiles against, can read it
  # without depending on `Billboard.Resource`, which reads the site's
  # answers. It depends on nothing of billboard's.

  @spec of(module()) :: :page | :version | :section | nil
  def of(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and Spark.Dsl.is?(module, Ash.Resource),
      do: Spark.Dsl.Extension.get_persisted(module, :billboard_resource)
  end
end
