defmodule Billboard.Directory.Page do
  @moduledoc """
  One page the builder knows, from the site's `pages` section
  (`Billboard.Site`). `pattern` is its route pattern (`nil` for the
  shared-sections library), `label` what the admin calls it, and `kind`
  which components it may use (each component's `kinds`); the library's
  is `:library`. `fixed` lists, in order, the sections a fixed page must
  have; it is `nil` on a page the admin arranges freely. `title` is its
  browser title when that isn't the hero's heading.
  """

  # Spark keeps source locations in `__spark_metadata__`, and needs
  # `__identifier__` on every entity struct.
  defstruct [
    :pattern,
    :label,
    :kind,
    fixed: nil,
    title: nil,
    __identifier__: nil,
    __spark_metadata__: nil
  ]

  @type t :: %__MODULE__{
          pattern: String.t() | nil,
          label: String.t(),
          kind: atom(),
          fixed: [atom()] | nil,
          title: String.t() | nil
        }
end
