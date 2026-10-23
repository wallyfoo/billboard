defmodule Billboard.Component.Transformers.AddSiteOptions do
  @moduledoc """
  Adds `Billboard.Changes.SiteOptions` to the component as a global
  change, as if it were written in the module:

      changes do
        change Billboard.Changes.SiteOptions, on: [:create, :update]
      end

  It goes after any global changes the component writes, so it sees what
  they set: a value one of them sets counts as given, and is kept. Ash
  runs an action's own changes before the global ones, and validations
  after both.

  No Ash transformer reads the changes. Ash's
  `ValidationsAndChangesForType` persister files them by action type,
  and persisters run after every transformer, so the change is there when
  it does. It still runs before every Ash resource transformer, as
  billboard's others do, so it's in place as if written by hand.
  """
  use Spark.Dsl.Transformer

  @impl true
  def before?(transformer), do: transformer in Ash.Resource.Dsl.transformers()

  @impl true
  def transform(dsl_state) do
    Ash.Resource.Builder.add_change(dsl_state, Billboard.Changes.SiteOptions,
      on: [:create, :update]
    )
  end
end
