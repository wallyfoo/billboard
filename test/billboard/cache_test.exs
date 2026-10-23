defmodule Billboard.CacheTest do
  use Billboard.Test.DataCase, async: false

  import ExUnit.CaptureLog

  alias Billboard.{Cache, Snapshot}
  alias Billboard.Test.{Repo, Shop}

  @opts [authorize?: false]

  setup :preserve_cache

  # These seed a live version straight into the database and refresh the
  # cache, as a commit would, for a page the rules wouldn't let commit.
  defp make_live(pattern, sections) do
    {:ok, page} = Shop.Pages.ensure_page(pattern, @opts)
    live = Ash.Seed.seed!(Shop.Version, %{page_id: page.id, status: :live})
    for {type, attrs, opts} <- sections, do: seed_section_fixture(live, type, attrs, opts)
    Cache.refresh()
    live
  end

  describe "starting" do
    test "loads the site's actions and context, whose atoms stored content holds" do
      modules = [Billboard.Test.Actions, Billboard.Test.Context]

      for module <- modules do
        :code.delete(module)
        :code.purge(module)
        refute :code.is_loaded(module)
      end

      :ok = Supervisor.terminate_child(Billboard.Test.Supervisor, Cache)
      {:ok, _pid} = Supervisor.restart_child(Billboard.Test.Supervisor, Cache)

      for module <- modules, do: assert({:file, _} = :code.is_loaded(module))
    end

    test "says which of the site's lists it couldn't read, and reads the other" do
      Billboard.Test.Env.put_site!(
        actions: Billboard.Test.RaisingActions,
        context: Billboard.Test.Context
      )

      :code.delete(Billboard.Test.Context)
      :code.purge(Billboard.Test.Context)

      log = capture_log(fn -> Cache.load_site_modules() end)

      assert log =~ "Reading kinds/0 of the site's `actions:` module failed"
      assert log =~ "Make kinds/0 return without raising"
      assert log =~ "the kinds are elsewhere"
      refute log =~ "bindings/0"

      # The context still loaded, so a stored binding's atom exists.
      assert {:file, _} = :code.is_loaded(Billboard.Test.Context)
      assert String.to_existing_atom("visit") in Keyword.keys(Billboard.Test.Context.bindings())
    end
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

      assert %{id: id, sections: [_hero, columns]} = Shop.Pages.page_for("/about")
      assert id == live.id
      assert Enum.map(columns.children, & &1.content.value.body) == ["Here", "Now"]
    end

    test "raises for a page the builder doesn't know" do
      assert_raise ArgumentError, ~r/no builder page/, fn -> Shop.Pages.page_for("/nowhere") end
    end
  end

  defp hero_of(draft),
    do: hd(Shop.Pages.get_version!(draft.id, @opts ++ [load: [:sections]]).sections)

  defp change_heading(draft, heading) do
    Shop.Pages.update_section!(
      hero_of(draft),
      %{content: %Ash.Union{type: :hero, value: %{heading: heading}}},
      @opts
    )
  end

  describe "committing" do
    test "puts the version in the snapshot and broadcasts it" do
      Shop.Pages.subscribe()
      {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      {:ok, _} = Shop.Pages.commit_page("/about", @opts)

      assert_receive {:pages_updated, _, %Snapshot{} = snapshot}
      assert snapshot.pages["/about"].id == draft.id
      assert Shop.Pages.page_for("/about").id == draft.id
    end

    test "replacing a live version refreshes the cache once" do
      {:ok, _first} = Shop.Pages.edit_page("/about", @opts)
      {:ok, _} = Shop.Pages.commit_page("/about", @opts)
      {:ok, second} = Shop.Pages.edit_page("/about", @opts)
      Shop.Pages.subscribe()

      {:ok, _} = Shop.Pages.commit_page("/about", @opts)

      # The notifications are sent, and so the broadcasts received, before
      # the commit returns. Other tests' refreshes can't hold this draft.
      assert refreshes_with("/about", second.id) == 1
    end

    test "tells the page's editors" do
      {:ok, _draft} = Shop.Pages.edit_page("/about", @opts)
      Shop.Pages.subscribe_page("/about")

      {:ok, _} = Shop.Pages.commit_page("/about", @opts)

      assert_receive {:page_draft_changed, "/about"}
    end
  end

  describe "drafts" do
    test "editing one tells the page's editors, and leaves the cache alone" do
      {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      Shop.Pages.subscribe()
      Shop.Pages.subscribe_page("/about")

      change_heading(draft, "Find us")

      assert_receive {:page_draft_changed, "/about"}
      refute_receive {:pages_updated, _, _}
      assert Shop.Pages.page_for("/about").status == :starter
    end

    test "making one tells the page's editors" do
      Shop.Pages.subscribe_page("/")
      {:ok, _draft} = Shop.Pages.edit_page("/", @opts)

      assert_receive {:page_draft_changed, "/"}
    end

    test "discarding one tells the page's editors, and leaves the cache alone" do
      {:ok, _draft} = Shop.Pages.edit_page("/about", @opts)
      Shop.Pages.subscribe()
      Shop.Pages.subscribe_page("/about")

      :ok = Shop.Pages.discard_page("/about", @opts)

      assert_receive {:page_draft_changed, "/about"}
      refute_receive {:pages_updated, _, _}
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

    test "can't be committed taking an anchor a page that places them already uses" do
      place_promo_beside_its_anchor()
      {:ok, _draft} = Shop.Pages.edit_page(nil, @opts)

      assert {:error, error} = Shop.Pages.commit_page(nil, @opts)
      assert Exception.message(error) =~ "Home"
      assert Exception.message(error) =~ "promo"
      assert Shop.Pages.page_for(nil).status == :starter
    end

    test "can be committed with an anchor no page that places them uses" do
      place_promo_beside_its_anchor()
      {:ok, draft} = Shop.Pages.edit_page(nil, @opts)
      band = Shop.Pages.get_section_by_key!(draft.id, "promo", @opts)
      Shop.Pages.update_section!(band, %{anchor: "visit-us"}, @opts)

      assert {:ok, _live} = Shop.Pages.commit_page(nil, @opts)
      assert Shop.Pages.shared_section("promo").anchor == "visit-us"
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

  # The home page places the library's promo band beside a Text section of
  # its own anchored "promo", the band's anchor in the library's starter.
  # The home page's own commit would refuse that, so it is seeded.
  defp place_promo_beside_its_anchor do
    make_live("/", [
      {:hero, %{heading: "Everything for the shop"}, %{position: 0}},
      {:text, %{body: "Come in."}, %{anchor: "promo", position: 1}},
      {:shared, %{key: "promo"}, %{position: 2}}
    ])
  end

  # The refresh broadcasts waiting in the mailbox whose snapshot shows
  # version `id` live at `pattern`.
  defp refreshes_with(pattern, id, count \\ 0) do
    receive do
      {:pages_updated, _node, %Snapshot{pages: %{^pattern => %{id: ^id}}}} ->
        refreshes_with(pattern, id, count + 1)
    after
      0 -> count
    end
  end
end
