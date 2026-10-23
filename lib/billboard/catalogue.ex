defmodule Billboard.Catalogue do
  @moduledoc """
  What the builder knows about each component: its label, its palette
  category, whether it mirrors, how many a page may hold, whether it fits
  in a column, which kinds of page may use it, and its placeholder. The
  component modules say what a section holds; this says where it may go.
  `Billboard.Surfaces` reads a component's surface kind and source
  itself.

  Each component declares its own in its `component` section
  (`Billboard.Component`), and this reads them, through
  `Billboard.Component.Info`, for the components the site lists
  (`Billboard.Site.components/0`). Entries are in that order, the
  palette's, which is also the order of the types in the site's content
  union (`Billboard.Content`).
  """
  alias Billboard.Catalogue.Entry
  alias Billboard.Component.Info
  alias Billboard.{Site, SiteOptions}

  @doc "Every entry, in palette order."
  @spec entries() :: [Entry.t()]
  def entries, do: Enum.map(Site.components(), &entry/1)

  @doc "Every component's key, in palette order."
  @spec keys() :: [atom()]
  def keys, do: Enum.map(Site.components(), &Info.component_key!/1)

  @doc """
  The entry for `key`, built from `Billboard.Site.component!/1`. Raises
  `KeyError` for an unknown key.
  """
  @spec fetch!(atom()) :: Entry.t()
  def fetch!(key) do
    if key in keys(),
      do: key |> Site.component!() |> entry(),
      else: raise(KeyError, key: key, term: __MODULE__)
  end

  @doc "The embedded resource for `key`."
  @spec module!(atom()) :: module()
  def module!(key), do: fetch!(key).module

  @doc "What the admin calls the component `key`."
  @spec label(atom()) :: String.t()
  def label(key), do: fetch!(key).label

  @doc """
  What a new section of `key` holds when it's added in the editor: enough
  to pass its validations, for the admin to write over. It's the
  component's placeholder less any value the site doesn't offer
  (`Billboard.SiteOptions.placeholder/1`), so the site's default takes
  its place.
  """
  @spec placeholder(atom()) :: map()
  def placeholder(key), do: fetch!(key).placeholder

  @doc """
  The palette's categories, in the order the site's components first
  name them, so the palette groups them in the order the site lists them.
  """
  @spec categories() :: [atom()]
  def categories, do: Site.components() |> Enum.map(&Info.component_category!/1) |> Enum.uniq()

  # Each option left out of the `component` section reads as its default.
  defp entry(module) do
    %Entry{
      key: Info.component_key!(module),
      module: module,
      label: Info.component_label!(module),
      category: Info.component_category!(module),
      hint: Info.component_hint!(module),
      mirror?: Info.component_mirror?(module),
      max: Info.component_max!(module),
      column?: Info.component_column?(module),
      kinds: Info.component_kinds!(module),
      placeholder: module |> Info.component_key!() |> SiteOptions.placeholder()
    }
  end
end
