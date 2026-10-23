defmodule Billboard.CacheNotifier do
  @moduledoc """
  Refreshes `Billboard.Cache` once a change commits to data the site's
  starters read, since the cache holds the starters. A site adds it to
  such a resource: `simple_notifiers: [Billboard.CacheNotifier]`. If the
  refresh fails, the cache is emptied instead, so the next read rebuilds
  it rather than serving an old starter.
  """
  use Ash.Notifier

  require Logger

  alias Billboard.Cache

  @impl true
  def notify(%Ash.Notifier.Notification{}) do
    Cache.refresh()
    :ok
  rescue
    error ->
      Logger.error("Pages cache refresh failed: " <> Exception.message(error))
      Cache.invalidate()
  end
end
