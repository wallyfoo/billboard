defmodule Billboard.Component.Part do
  @moduledoc """
  A `part` in a component's `component` section: one part, held in an
  attribute of its own. `Billboard.Component` documents the options.
  """

  # Spark 2.7 needs `__spark_metadata__` on every entity struct, where it
  # keeps source locations for errors, and `__identifier__` on an entity
  # that declares an `identifier:`, as both part entities do (the name).
  defstruct [
    :name,
    :type,
    :default,
    :description,
    allow_nil?: true,
    __identifier__: nil,
    __spark_metadata__: nil
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: module(),
          allow_nil?: boolean(),
          default: struct() | nil,
          description: String.t() | nil
        }
end
