defmodule Billboard.Pages do
  @moduledoc """
  The page engine's functions. Each page has at most two versions: the
  live one, and a draft of uncommitted changes. A page's record is made
  on its first edit. The site's domain (`Billboard.Domain`) delegates
  these by the same names, so a site calls `MySite.Pages.page_for/1`.

  They reach the site's resources through its domain's code interfaces
  (`Billboard.Site.domain!/0`), which `use Billboard.Domain` defines.
  """

  alias Billboard.{Cache, Directory, Site, Snapshot}

  @doc """
  The page record for `pattern` (`nil` for the library), made if it has
  none. A page's first edit makes it, through `Billboard.Version.Edit`.
  """
  def ensure_page(pattern, opts \\ []) do
    case existing_page(pattern, opts) do
      {:ok, nil} -> domain().create_page(%{pattern: pattern}, opts)
      other -> other
    end
  end

  @doc """
  Drops the `{:page_draft_changed, pattern}` messages waiting in the
  caller's mailbox. A change arrives as a burst, one message per row, and
  an editor that has just made a change reads the page itself, so it
  needn't read it again for each of its own messages.
  """
  def drain_page_changes(pattern) do
    receive do
      {:page_draft_changed, ^pattern} -> drain_page_changes(pattern)
    after
      0 -> :ok
    end
  end

  @doc """
  What the page at route `pattern` (`nil` for the shared-sections library)
  shows visitors: its live version, else its starter. Both come from
  `Billboard.Cache`, with their sections and the sections' children
  loaded, so this never reads the database while the cache is full.

  Raises `ArgumentError` for a page the builder doesn't know.
  """
  @spec page_for(String.t() | nil) :: struct()
  def page_for(pattern) do
    Snapshot.page(Cache.snapshot(), pattern) || Site.starter(Directory.fetch!(pattern).pattern)
  end

  @doc """
  The shared-library sections by key: its live version's, else its
  starter's.
  """
  @spec shared_sections() :: %{String.t() => struct()}
  def shared_sections, do: Map.new(page_for(nil).sections, &{&1.key, &1})

  @doc "The shared-library section with `key`, or `nil` if it has left the library."
  @spec shared_section(String.t()) :: struct() | nil
  def shared_section(key), do: Map.get(shared_sections(), key)

  @doc """
  Subscribes the caller to what visitors see. Each change, a commit or a
  change to the data behind a starter, arrives as
  `{:pages_updated, node, %Billboard.Snapshot{}}`.
  """
  def subscribe, do: Phoenix.PubSub.subscribe(Site.pubsub!(), Cache.topic())

  @doc """
  Subscribes the caller to `pattern`'s page, as its editors do. Any
  change to its draft, including making, committing, or discarding it,
  arrives as `{:page_draft_changed, pattern}`.
  """
  def subscribe_page(pattern),
    do: Phoenix.PubSub.subscribe(Site.pubsub!(), page_topic(pattern))

  @doc "Undoes `subscribe_page/1`, as an editor does when it leaves a page."
  def unsubscribe_page(pattern),
    do: Phoenix.PubSub.unsubscribe(Site.pubsub!(), page_topic(pattern))

  @doc "The PubSub topic for `pattern`'s page (`nil` for the library)."
  def page_topic(nil), do: "pages:shared"
  def page_topic(pattern), do: "pages:page:" <> pattern

  defp existing_page(nil, opts), do: domain().fetch_library_page(opts)
  defp existing_page(pattern, opts), do: domain().fetch_page(pattern, opts)

  defp domain, do: Site.domain!()
end
