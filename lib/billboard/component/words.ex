defmodule Billboard.Component.Words do
  @moduledoc """
  One `words` entry in a component's `editor` section: words typed in
  place, with their soft limit for the counter. `Billboard.Component`
  documents the options.
  """
  defstruct [
    :name,
    :as,
    :label,
    :hint,
    :hide_when,
    :bound,
    :limit,
    more: false,
    accent: false,
    __identifier__: nil,
    __spark_metadata__: nil
  ]

  @type t :: %__MODULE__{}
end
