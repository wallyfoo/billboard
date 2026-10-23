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

  A site narrows a component, by its key, in `use Billboard.Site`: its
  `kinds:` keeps a component to some kinds of page, over the
  component's own `kinds`, and its `palette:` gives a component a hint
  of the site's own (`hints:`) and labels the palette's categories
  (`categories:`, read by `category_label/1`).
  """
  alias Billboard.Catalogue.Entry
  alias Billboard.Component.Info
  alias Billboard.{Site, SiteOptions}

  @labels [
    opener: "Openers",
    band: "Bands",
    content: "On the page",
    data: "From the site's records",
    layout: "Layout",
    special: "From the shared library"
  ]

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

  @doc """
  What the palette calls `category`: the site's label for it
  (`palette: [categories: …]`), billboard's for its stock categories, or
  its name, as "Odds and ends" for `:odds_and_ends`.
  """
  @spec category_label(atom()) :: String.t()
  def category_label(category) do
    Keyword.get(Site.palette()[:categories] || [], category) ||
      Keyword.get(@labels, category) ||
      category |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  # Each option left out of the `component` section reads as its default,
  # and the site's narrowing, by key, stands over the component's own.
  defp entry(module) do
    key = Info.component_key!(module)

    %Entry{
      key: key,
      module: module,
      label: Info.component_label!(module),
      category: Info.component_category!(module),
      hint: Keyword.get(Site.palette()[:hints] || [], key, Info.component_hint!(module)),
      mirror?: Info.component_mirror?(module),
      max: Info.component_max!(module),
      column?: Info.component_column?(module),
      kinds: Keyword.get(Site.kinds(), key, Info.component_kinds!(module)),
      placeholder: SiteOptions.placeholder(key)
    }
  end
end
