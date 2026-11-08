defmodule Billboard.MigrateSectionsTest do
  @moduledoc """
  `Billboard.Pages.migrate_sections/3`, through the shop's domain: every
  stored section of a key, live, drafted, and in the library, moved to
  another component or deleted, in one transaction.
  """
  use Billboard.Test.DataCase, async: false

  # Each refresh of the cache warns of the leaflets still live.
  @moduletag :capture_log

  alias Billboard.Pages
  alias Billboard.Test.Shop

  @opts [authorize?: false]

  setup :preserve_cache

  defp hero, do: %{type: :hero, content: %{heading: "About us"}}
  defp band, do: %{type: :band, content: %{heading: "Visit"}}

  defp types(version), do: Enum.map(version.sections, & &1.content.type)

  # Sections of `leaflet`, a component the shop has never had: one on the
  # live about page, which its draft copies, one only in that draft, and
  # one in the live library.
  setup do
    {:ok, live} = Shop.Pages.put_page("/about", [hero()], @opts)

    live_key =
      stored_section_fixture(live, :leaflet, %{"title" => "Fees", "service" => "therapy"},
        position: 1
      )

    {:ok, draft} = Shop.Pages.edit_page("/about", @opts)

    draft_key =
      stored_section_fixture(draft, :leaflet, %{"title" => "More fees", "fail" => true},
        position: 2
      )

    {:ok, library} = Shop.Pages.put_page(nil, [band()], @opts)

    library_key =
      stored_section_fixture(library, :leaflet, %{"title" => "Shared fees"}, position: 1)

    Billboard.Cache.refresh()

    %{
      live: live,
      library: library,
      live_key: live_key,
      draft_key: draft_key,
      library_key: library_key
    }
  end

  defp draft, do: Pages.draft_for("/about", @opts) |> elem(1)

  defp to_prices(fields) do
    {:prices, %{head: %{heading: fields["title"]}, group: fields["service"]}}
  end

  test "moves every one, live, drafted, and in the library, mapping its fields", ctx do
    assert {:ok, migrated} = Shop.Pages.migrate_sections(:leaflet, &to_prices/1)

    assert migrated == [
             %{page: nil, version: :live, key: ctx.library_key, to: :prices},
             %{page: "/about", version: :draft, key: ctx.live_key, to: :prices},
             %{page: "/about", version: :draft, key: ctx.draft_key, to: :prices},
             %{page: "/about", version: :live, key: ctx.live_key, to: :prices}
           ]

    live = Pages.page_for("/about")
    assert types(live) == [:hero, :prices]
    [_hero, prices] = live.sections
    assert prices.key == ctx.live_key
    assert prices.content.value.head.heading == "Fees"
    assert prices.content.value.group == "therapy"
    assert stored_content(ctx.live.id, ctx.live_key)["type"] == "prices"

    assert types(draft()) == [:hero, :prices, :prices]
    assert Enum.at(draft().sections, 2).content.value.head.heading == "More fees"
    assert types(Pages.page_for(nil)) == [:band, :prices]

    # Nothing is left for the rules to refuse.
    assert {:ok, _live} = Shop.Pages.commit_page("/about", @opts)
  end

  test "takes the stored fields as they are, given only a key" do
    {:ok, live} = Shop.Pages.put_page("/", [hero()], @opts)
    key = stored_section_fixture(live, :old_text, %{"body" => "Kept"})

    assert {:ok, [%{page: "/", version: :live, key: ^key, to: :text}]} =
             Shop.Pages.migrate_sections("old_text", :text)

    assert [_hero, words] = Pages.page_for("/").sections
    assert words.content.value.body == "Kept"
  end

  test "deletes every one, when the function says so", ctx do
    assert {:ok, migrated} = Shop.Pages.migrate_sections(:leaflet, fn _fields -> :delete end)
    assert length(migrated) == 4
    assert Enum.all?(migrated, &(&1.to == :deleted))

    assert types(Pages.page_for("/about")) == [:hero]
    assert types(draft()) == [:hero]
    assert types(Pages.page_for(nil)) == [:band]

    assert Shop.Pages.get_section_by_key(ctx.library.id, ctx.library_key, @opts) |> elem(0) ==
             :error
  end

  test "with dry_run: true, says what it would do, and does nothing" do
    assert {:ok, migrated} = Shop.Pages.migrate_sections(:leaflet, &to_prices/1, dry_run: true)
    assert length(migrated) == 4

    assert types(Pages.page_for("/about")) == [:hero, :retired]
    assert types(draft()) == [:hero, :retired, :retired]
    assert types(Pages.page_for(nil)) == [:band, :retired]
  end

  test "a section whose new content doesn't build changes nothing, and is named", ctx do
    too_long = fn fields ->
      if fields["fail"],
        do: {:prices, %{body: String.duplicate("x", 700)}},
        else: to_prices(fields)
    end

    assert {:error, %{page: "/about", version: :draft, key: key, error: %Ash.Error.Invalid{}}} =
             Shop.Pages.migrate_sections(:leaflet, too_long)

    assert key == ctx.draft_key

    # The library's, migrated first, went back with the rest.
    assert types(Pages.page_for(nil)) == [:band, :retired]
    assert stored_content(ctx.library.id, ctx.library_key)["type"] == "leaflet"
  end

  test "tells each changed page's editors" do
    Pages.subscribe_page("/about")
    Pages.subscribe_page(nil)
    {:ok, _migrated} = Shop.Pages.migrate_sections(:leaflet, fn _fields -> :delete end)

    assert_receive {:page_draft_changed, "/about"}
    assert_receive {:page_draft_changed, nil}
  end

  test "finds nothing to do for a key with no sections" do
    assert Shop.Pages.migrate_sections(:nothing_stored, :text) == {:ok, []}
  end

  test "raises for a component the site doesn't list, or a function's other answer" do
    assert_raise ArgumentError, ~r/:nope isn't one. Add its module to `components:`/, fn ->
      Shop.Pages.migrate_sections(:leaflet, :nope)
    end

    assert_raise ArgumentError, ~r/returns `\{key, fields\}` or `:delete`/, fn ->
      Shop.Pages.migrate_sections(:leaflet, fn _fields -> :keep end)
    end

    assert types(Pages.page_for("/about")) == [:hero, :retired]
  end
end
