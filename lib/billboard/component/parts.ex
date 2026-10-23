defmodule Billboard.Component.Parts do
  @moduledoc """
  A `parts` in a component's `component` section: a list of parts, held in
  one attribute. `Billboard.Component` documents the options.
  """

  # See `Billboard.Component.Part` for the two Spark fields.
  defstruct [
    :name,
    :type,
    :min,
    :max,
    :description,
    allow_nil?: false,
    __identifier__: nil,
    __spark_metadata__: nil
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: module(),
          min: non_neg_integer() | nil,
          max: pos_integer() | nil,
          allow_nil?: boolean(),
          description: String.t() | nil
        }
end
