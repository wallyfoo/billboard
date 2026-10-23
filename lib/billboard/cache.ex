defmodule Billboard.Cache do
  @moduledoc """
  What each builder page shows visitors (`Billboard.Snapshot`), held in
  ETS so public pages read it without touching the database.

  Making a version live refreshes the cache (`Billboard.Notifier`), as
  does any change to data the site's starters read
  (`Billboard.CacheNotifier`): the process that made the change rebuilds
  the snapshot from the database once its transaction commits, stores
  it, and broadcasts it on `topic/0`, so open pages redraw. Other nodes
  only invalidate on that broadcast; their next read rebuilds from the
  database, which by then holds the change.

  A read that finds the cache empty builds it, so a failed warm-up at
  boot, or an invalidation, costs one database read rather than a broken
  page.

  A site starts it in its supervision tree, after its repo and PubSub,
  and before its endpoint or anything else that reads content:

      children = [MySite.Repo, {Phoenix.PubSub, name: MySite.PubSub}, Billboard.Cache, …]

  It needs the site configured (`config :billboard, site: MySite.Billboard`)
  and the site's `pubsub:` answer, which it broadcasts on. Without
  either, its start fails, naming the fix. Before it warms, it loads the
  site's `actions:` and `context:` modules, since stored content holds
  atoms only they name.
  """
  use GenServer

  require Logger

  alias Billboard.Snapshot

  @table __MODULE__
  @topic "pages:live"

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  The PubSub topic that carries `{:pages_updated, node, snapshot}`.
  """
  def topic, do: @topic

  @doc """
  The current snapshot, built from the database if the cache is empty.
  A snapshot built inside a transaction is returned but never stored.
  """
  def snapshot do
    case stored() do
      {:ok, snapshot} -> snapshot
      :error -> load(:if_empty)
    end
  end

  @doc """
  Rebuilds the snapshot from the database, stores it, and broadcasts it.
  """
  def refresh do
    snapshot = load(:always)

    Phoenix.PubSub.broadcast(
      Billboard.Site.pubsub!(),
      @topic,
      {:pages_updated, node(), snapshot}
    )

    snapshot
  end

  @doc """
  Empties the cache, so the next read rebuilds it.
  """
  def invalidate do
    :ets.delete(@table, :snapshot)
    :ok
  end

  @doc """
  Stores `snapshot` as it is. Tests use it to put back the snapshot they
  started with.
  """
  def put(%Snapshot{} = snapshot) do
    :ets.insert(@table, {:snapshot, snapshot})
    :ok
  end

  defp stored do
    case :ets.lookup(@table, :snapshot) do
      [{:snapshot, snapshot}] -> {:ok, snapshot}
      [] -> :error
    end
  end

  # A build inside a transaction reads that transaction's uncommitted
  # changes, which may yet roll back, or which other processes can't see.
  # It serves its caller, but never the cache.
  defp load(mode) do
    if Billboard.Site.repo!().in_transaction?(),
      do: Snapshot.build(),
      else: load_and_store(mode)
  end

  # Builds on this node take turns, so a build that read the database
  # earlier can never overwrite one that read it later. A read of an empty
  # cache checks again once it has its turn: when several readers find it
  # empty at once, the first builds it and the rest read that build. A
  # refresh always builds.
  defp load_and_store(mode) do
    :global.trans(
      {__MODULE__, self()},
      fn ->
        case {mode, stored()} do
          {:if_empty, {:ok, snapshot}} ->
            snapshot

          _rebuild ->
            snapshot = Snapshot.build()
            :ets.insert(@table, {:snapshot, snapshot})
            snapshot
        end
      end,
      [node()]
    )
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    Phoenix.PubSub.subscribe(Billboard.Site.pubsub!(), @topic)
    load_site_modules()
    warm()
    {:ok, %{}}
  end

  @impl true
  def handle_info({:pages_updated, origin, _snapshot}, state) do
    if origin != node(), do: invalidate()
    {:noreply, state}
  end

  # Stored content holds some atoms that only the site's own modules
  # name, such as an action's kind (`:visit`) or a hero's binding, and Ash
  # casts them back with `String.to_existing_atom/1`. A release loads
  # every module at boot, but where code loads on demand, as under
  # `mix phx.server`, such an atom doesn't exist until its module loads,
  # and the first read of a section that holds it would fail. So the
  # modules that name them load before anything reads content, and their
  # lists are read once, so the atoms exist even when a site builds its
  # lists rather than writing them out. Components and parts need
  # nothing: Ash calls into each before it casts its attributes, which
  # loads it.
  defp load_site_modules do
    for module <- [Billboard.Site.actions(), Billboard.Site.context()], module do
      Code.ensure_loaded(module)
    end

    _ = Billboard.Actions.kinds()
    _ = Billboard.Context.bindings()
  rescue
    error ->
      Logger.warning(
        "Loading the site's actions and context failed, so content that names their atoms " <>
          "may not read. Make their `kinds/0` and `bindings/0` return without raising. " <>
          Exception.message(error)
      )
  end

  defp warm do
    load(:always)
  rescue
    error ->
      Logger.warning(
        "Pages cache warm-up failed; the first read will fill it. " <>
          Exception.message(error)
      )
  end
end
