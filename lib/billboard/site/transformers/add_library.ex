defmodule Billboard.Site.Transformers.AddLibrary do
  @moduledoc """
  Adds the shared-sections library, as `library "Shared sections"`, after
  the site's pages when it doesn't write one. Every site has a library,
  since a Shared section on any page draws from it.
  """
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    if Enum.any?(Transformer.get_entities(dsl_state, [:pages]), &is_nil(&1.pattern)) do
      {:ok, dsl_state}
    else
      library =
        Transformer.build_entity!(Billboard.Site.Dsl, [:pages], :library,
          label: "Shared sections"
        )

      {:ok, Transformer.add_entity(dsl_state, [:pages], library, type: :append)}
    end
  end
end
