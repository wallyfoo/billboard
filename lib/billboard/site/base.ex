defmodule Billboard.Site.Base do
  @moduledoc false
  # The Spark DSL under `use Billboard.Site`, which holds its `pages`
  # section and runs its transformers and verifiers. `Billboard.Site`
  # documents it; a site never uses this module itself.
  use Spark.Dsl, default_extensions: [extensions: [Billboard.Site.Dsl]]
end
