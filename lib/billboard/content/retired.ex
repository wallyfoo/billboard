defmodule Billboard.Content.Retired do
  @moduledoc """
  A stored section of a component the site no longer has: one whose key
  isn't among the site's `components:`, as when a site replaces a
  component of its own with a stock one and takes its module out of the
  list. Reading it never fails. The site's content union
  (`Billboard.Content`) reads its content as
  `%Ash.Union{type: :retired, value: %Billboard.Content.Retired{}}`,
  which holds:

    * `component`, the key it's stored under, as a string, such as
      `"fees"`;
    * `fields`, its fields as they're stored, less the `component` tag:
      a map with string keys, its parts maps too.

  It's written back exactly as it was read, so a draft made from a live
  version holds it as the live version did, under its old key.

  Visitors' pages draw nothing for it, and billboard logs a warning
  naming the key and the page each time it reads the live pages into
  `Billboard.Cache`. The page editor draws a stand-in for it, saying the
  site no longer has its component, and its header offers Remove.
  Publishing a page that holds one is refused until it's removed or
  migrated (`Billboard.Rules`). `Billboard.Pages.migrate_sections/3`
  moves every stored section of a key to another component, or deletes
  them, and the page kinds guide's "Retiring a component" walks through
  both.

  `:retired` is the union's own, so no component may take it as its key.
  """
  use Ash.Type

  defstruct [:component, fields: %{}]

  @type t :: %__MODULE__{component: String.t(), fields: map()}

  @doc """
  Whether `section` holds a retired component's content.
  """
  @spec retired?(map()) :: boolean()
  def retired?(%{content: %Ash.Union{type: :retired}}), do: true
  def retired?(_section), do: false

  @doc """
  The admin's words for a retired section: what the page editor's
  stand-in and its header call it, and how a rule names it.
  """
  @spec label(map()) :: String.t()
  def label(%{content: %Ash.Union{value: %__MODULE__{component: component}}}),
    do: "Retired component “#{component}”"

  @impl true
  def storage_type(_constraints), do: :map

  # Only the struct itself is this type's input, so a map sent as a
  # section's content, as the editor's forms send it, never makes one.
  @impl true
  def cast_input(nil, _constraints), do: {:ok, nil}
  def cast_input(%__MODULE__{} = retired, _constraints), do: {:ok, retired}
  def cast_input(_value, _constraints), do: :error

  # `Billboard.Content` reads and writes a retired section under its own
  # key; these are only Ash's, for the type on its own.
  @impl true
  def cast_stored(nil, _constraints), do: {:ok, nil}

  def cast_stored(%{"component" => component, "fields" => fields}, _constraints),
    do: {:ok, %__MODULE__{component: component, fields: fields}}

  def cast_stored(_value, _constraints), do: :error

  @impl true
  def dump_to_native(nil, _constraints), do: {:ok, nil}

  def dump_to_native(%__MODULE__{component: component, fields: fields}, _constraints),
    do: {:ok, %{"component" => component, "fields" => fields}}

  def dump_to_native(_value, _constraints), do: :error
end
