defmodule Billboard.Notifier do
  @moduledoc """
  After a change to a version or a section commits, tells the page's
  editors (`Billboard.Pages.subscribe_page/1`). When the change made a
  version live, it also refreshes `Billboard.Cache`, which redraws open
  public pages. A commit deletes the old live version before it makes
  the draft live, in the same transaction, so refreshing once, on
  `:make_live`, covers both. Live sections never change, so a section
  change never touches the cache.

  If telling them fails, the cache is emptied instead, so the next read
  rebuilds it rather than serving an old page.
  """
  use Ash.Notifier

  require Logger

  alias Billboard.Cache

  @impl true
  def notify(%Ash.Notifier.Notification{resource: resource, action: action, data: data}) do
    kind = Billboard.Resource.kind(resource)

    case page(kind, resource, data) do
      {:ok, %{pattern: pattern}} ->
        Phoenix.PubSub.broadcast(
          Billboard.Site.pubsub!(),
          Billboard.Pages.page_topic(pattern),
          {:page_draft_changed, pattern}
        )

        if kind == :version and action.name == :make_live, do: Cache.refresh()
        :ok

      {:ok, nil} ->
        :ok

      {:error, error} ->
        failed(error)
    end
  rescue
    error -> failed(error)
  end

  # A record that has gone is nothing to tell anyone about (`{:ok, nil}`).
  # A section's version is gone when a discard or a commit deleted it, and
  # then the version's own notification tells the page. And when an action
  # in a transaction fails, Ash leaves the notifications of the writes it
  # rolled back queued in the process, and sends them with the next action
  # that process runs, even a plain read, for records that never existed.
  defp page(:version, resource, version),
    do:
      Ash.get(Billboard.Resource.related(resource, :page), version.page_id,
        authorize?: false,
        not_found_error?: false
      )

  defp page(:section, resource, section) do
    case Ash.get(Billboard.Resource.related(resource, :version), section.version_id,
           load: [:page],
           authorize?: false,
           not_found_error?: false
         ) do
      {:ok, %{page: page}} -> {:ok, page}
      other -> other
    end
  end

  defp failed(error) do
    Logger.error("Pages notification failed: " <> Exception.message(error))
    Cache.invalidate()
  end
end
