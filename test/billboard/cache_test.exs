defmodule Billboard.CacheTest do
  use Billboard.Test.DataCase, async: false

  import ExUnit.CaptureLog

  alias Billboard.{Cache, Snapshot}
  alias Billboard.Test.{Repo, Shop}

  @opts [authorize?: false]

  setup :preserve_cache

  # Committing is the engine's, so these seed the live version straight
  # into the database and refresh the cache, as a commit would.
  defp make_live(pattern, sections) do
    {:ok, page} = Shop.Pages.ensure_page(pattern, @opts)
    live = Ash.Seed.seed!(Shop.Version, %{page_id: page.id, status: :live})
    for {type, attrs, opts} <- sections, do: seed_section_fixture(live, type, attrs, opts)
    Billboard.Cache.refresh()
    live
  end

  describe "page_for/1" do
    test "a page that has never been committed renders its starter" do
      assert %{status: :starter} = Shop.Pages.page_for("/about")
    end

    test "a live version comes with its sections and their children" do
      live =
        make_live("/about", [
          {:hero, %{heading: "About us"}, %{position: 0}},
          {:columns, %{}, %{key: "visit", position: 1}}
        ])

      columns = Shop.Pages.get_section_by_key!(live.id, "visit", @opts)
      seed_section_fixture(live, :text, %{body: "Here"}, %{parent_id: columns.id, position: 0})
      seed_section_fixture(live, :text, %{body: "Now"}, %{parent_id: columns.id, position: 1})
      Cache.refresh()

      assert [_hero, columns] = Shop.Pages.page_for("/about").sections
      assert [_here, _now] = columns.children
    end

    test "raises for a page the builder doesn't know" do
      assert_raise ArgumentError, ~r/no builder page/, fn -> Shop.Pages.page_for("/nowhere") end
    end
  end

  describe "starters" do
    test "are held in the snapshot, until the page has a live version" do
      snapshot = Cache.refresh()
      assert %{status: :starter} = snapshot.starters["/about"]

      live = make_live("/about", [{:hero, %{heading: "About us"}, %{}}])

      refute Map.has_key?(Cache.snapshot().starters, "/about")
      assert Cache.snapshot().pages["/about"].id == live.id
    end

    test "aren't held when the strict starter fails, and are built on each render instead" do
      put_env_for_test(:billboard, :failing_starters, ["/about"])

      {snapshot, log} = with_log(&Snapshot.build/0)

      assert log =~ "left out of the pages cache"
      assert log =~ "/about"
      refute Map.has_key?(snapshot.starters, "/about")

      Cache.put(snapshot)
      assert %{status: :starter} = Shop.Pages.page_for("/about")
    end
  end

  describe "shared sections" do
    test "come from the library's starter" do
      assert %{content: %{type: :band}} = Shop.Pages.shared_section("promo")
      assert Shop.Pages.shared_section("no-such-section") == nil
    end

    test "come from the library's live version once it is live" do
      make_live(nil, [
        {:band, %{heading: "Visit the shop"}, %{key: "promo", position: 0}},
        {:text, %{body: "Quiet"}, %{key: "quiet", position: 1}}
      ])

      assert Shop.Pages.shared_sections() |> Map.keys() |> Enum.sort() == ["promo", "quiet"]
      assert %{content: %{type: :text}} = Shop.Pages.shared_section("quiet")
    end
  end

  describe "the pages cache itself" do
    test "a refresh rebuilds the snapshot, stores it, and broadcasts it" do
      Shop.Pages.subscribe()
      Cache.put(%Snapshot{})

      snapshot = Cache.refresh()

      assert %{status: :starter} = snapshot.starters["/about"]
      assert_receive {:pages_updated, _node, ^snapshot}
      assert Cache.snapshot() == snapshot
    end

    test "a read of a full cache doesn't rebuild it" do
      Cache.put(%Snapshot{})
      assert Cache.snapshot() == %Snapshot{}
    end

    test "rebuilds from the database after an invalidation" do
      Cache.invalidate()
      assert %{status: :starter} = Cache.snapshot().starters["/about"]
    end

    test "a read inside a transaction builds a snapshot but doesn't store it" do
      Cache.invalidate()

      assert {:ok, %Snapshot{} = snapshot} = Repo.transaction(&Cache.snapshot/0)
      assert Map.has_key?(snapshot.starters, "/about")
      assert :ets.lookup(Cache, :snapshot) == []
    end

    test "only invalidates when the change came from another node" do
      snapshot = %Snapshot{}
      Cache.put(snapshot)

      # This node stored its own change before broadcasting it.
      send(Cache, {:pages_updated, node(), snapshot})
      _ = :sys.get_state(Cache)
      assert :ets.lookup(Cache, :snapshot) == [{:snapshot, snapshot}]

      send(Cache, {:pages_updated, :other@host, snapshot})
      _ = :sys.get_state(Cache)
      assert :ets.lookup(Cache, :snapshot) == []
    end
  end

  describe "the cache notifier" do
    test "refreshes the cache" do
      Shop.Pages.subscribe()

      assert :ok = Billboard.CacheNotifier.notify(%Ash.Notifier.Notification{})

      assert_receive {:pages_updated, _, %Snapshot{}}
    end

    test "empties the cache when the refresh fails" do
      {:ok, log} =
        without_table("billboard_versions", fn ->
          with_log(fn -> Billboard.CacheNotifier.notify(%Ash.Notifier.Notification{}) end)
        end)

      assert :ets.lookup(Cache, :snapshot) == []
      assert log =~ "Pages cache refresh failed"
      assert log =~ "billboard_versions"
    end
  end
end
