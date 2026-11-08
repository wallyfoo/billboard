defmodule Billboard.Snapshot do
  @moduledoc """
  What each builder page shows visitors, read in one go: its live
  version, with its sections and their children, once it has been
  committed (`pages`), and its starter until then (`starters`).
  `Billboard.Cache` holds one.

  Starters are built here, once per snapshot, rather than on every
  render: they may read the site's own data, so a change to that data
  should refresh the cache too (`Billboard.CacheNotifier`). A starter
  whose data can't be read is left out, rather than kept with its
  defaults, and `Billboard.Pages.page_for/1` builds it on each render
  until the next snapshot.

  A live section of a component the site no longer has
  (`Billboard.Content.Retired`) stays in its version, which the editor
  reads, and visitors' pages draw nothing for it. Each build logs a
  warning for each one, naming its key and its page, so it's said once
  each time the cache is filled, at start-up and after each publish,
  rather than on every visit.
  """
  require Logger

  alias Billboard.Directory

  defstruct pages: %{}, starters: %{}

  @type pattern :: String.t() | nil

  @type t :: %__MODULE__{
          pages: %{pattern() => struct()},
          starters: %{pattern() => struct()}
        }

  @doc """
  Reads the live versions from the database, and builds the starter of
  every page that has none.
  """
  def build do
    live =
      Map.new(
        Billboard.Site.domain!().list_live_versions!(authorize?: false),
        &{&1.page.pattern, &1}
      )

    Enum.each(live, fn {pattern, version} -> warn_retired(pattern, version) end)

    %__MODULE__{
      pages: live,
      starters:
        for(
          %{pattern: pattern} <- Directory.pages(),
          not Map.has_key?(live, pattern),
          {:ok, starter} <- [starter(pattern)],
          into: %{},
          do: {pattern, starter}
        )
    }
  end

  defp warn_retired(pattern, version) do
    for section <- Enum.flat_map(version.sections, &[&1 | &1.children]),
        Billboard.Content.Retired.retired?(section) do
      Logger.warning(
        "The live #{page_name(pattern)} holds a section of “#{section.content.value.component}”, " <>
          "a component the site no longer has, so visitors don't see it (section " <>
          "#{inspect(section.key)}). Remove it in the page editor, or migrate it with " <>
          "Billboard.Pages.migrate_sections/3."
      )
    end
  end

  defp page_name(nil), do: "shared library"
  defp page_name(pattern), do: "page #{pattern}"

  # Strict, so a failed read never leaves defaults in the cache. One
  # page's failure costs only that page its place.
  defp starter(pattern) do
    {:ok, Billboard.Site.starter!(pattern)}
  rescue
    error ->
      Logger.error(
        "Starter for #{inspect(pattern)} left out of the pages cache: " <>
          Exception.message(error)
      )

      :error
  end

  @doc """
  What the builder page at route `pattern` (`nil` for the shared-sections
  library) shows visitors: its live version, else its starter, or `nil`
  for a page the builder doesn't know.
  """
  @spec page(t(), pattern()) :: struct() | nil
  def page(%__MODULE__{pages: pages, starters: starters}, pattern),
    do: Map.get(pages, pattern) || Map.get(starters, pattern)
end
