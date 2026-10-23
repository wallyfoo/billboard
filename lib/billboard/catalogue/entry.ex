defmodule Billboard.Catalogue.Entry do
  @moduledoc """
  One component as the builder knows it, read from its `component`
  section (`Billboard.Component`). `key` is its tag in the site's content
  union, `module` its embedded resource, and `label` and `hint` what the
  palette shows. `category` places it in the palette. `mirror?` marks a
  component with image-left and image-right variants. `max` caps how many
  a page may hold (`nil` for no cap), `column?` lets it sit in two
  columns, and `kinds` lists the kinds of page that may use it, or is
  `:all` (`allows?/2`). `placeholder` is what a new section of it holds
  when it's added in the editor, less any value the site doesn't offer.
  """
  @enforce_keys [:key, :module, :label, :category, :hint]
  defstruct [
    :key,
    :module,
    :label,
    :category,
    :hint,
    mirror?: false,
    max: nil,
    column?: false,
    kinds: :all,
    placeholder: %{}
  ]

  @type t :: %__MODULE__{
          key: atom(),
          module: module(),
          label: String.t(),
          category: atom(),
          hint: String.t(),
          mirror?: boolean(),
          max: pos_integer() | nil,
          column?: boolean(),
          kinds: :all | [atom()],
          placeholder: map()
        }

  @doc "Whether a page of `kind` may use the component."
  @spec allows?(t(), atom()) :: boolean()
  def allows?(%__MODULE__{kinds: :all}, _kind), do: true
  def allows?(%__MODULE__{kinds: kinds}, kind), do: kind in kinds
end
