defmodule Billboard.Guides.RetireFeesTest do
  @moduledoc """
  The page kinds guide's "Retiring a component" (`MySite.Pages.RetireFees`):
  the guide's own Fees, moved to the stock Prices, its fields mapped, or
  deleted, wherever it's stored. The shop still lists Fees; a key it
  doesn't is `Billboard.MigrateSectionsTest`'s.
  """
  use Billboard.Test.DataCase, async: false

  alias Billboard.Pages
  alias Billboard.Test.Shop

  @opts [authorize?: false]

  setup :preserve_cache

  defp hero, do: %{type: :hero, content: %{heading: "Fees"}}

  defp fees(title, this_service_only),
    do: %{type: :fees, content: %{title: title, this_service_only: this_service_only}}

  defp types(version), do: Enum.map(version.sections, & &1.content.type)

  # Fees on the about page, live and in its draft, and in the library.
  setup do
    {:ok, _live} = Shop.Pages.put_page("/about", [hero(), fees("What it costs", true)], @opts)
    {:ok, _draft} = Shop.Pages.edit_page("/about", @opts)
    {:ok, _library} = Shop.Pages.put_page(nil, [fees(nil, false)], @opts)
    :ok
  end

  test "a dry run counts every Fees section, and changes none" do
    assert {:ok, migrated} = MySite.Pages.RetireFees.to_prices(dry_run: true)
    assert length(migrated) == 3
    assert types(Pages.page_for("/about")) == [:hero, :fees]
  end

  test "moves every Fees section to Prices, its fields mapped" do
    assert {:ok, migrated} = MySite.Pages.RetireFees.to_prices()

    assert Enum.map(migrated, &{&1.page, &1.version, &1.to}) == [
             {nil, :live, :prices},
             {"/about", :draft, :prices},
             {"/about", :live, :prices}
           ]

    [_hero, prices] = Pages.page_for("/about").sections
    assert prices.content.value.head.heading == "What it costs"
    assert prices.content.value.this_page_only
    assert prices.content.value.group == nil

    [library] = Pages.page_for(nil).sections
    assert library.content.value.head == nil
    refute library.content.value.this_page_only

    {:ok, draft} = Pages.draft_for("/about", @opts)
    assert types(draft) == [:hero, :prices]
  end

  test "deletes every Fees section" do
    assert {:ok, migrated} = MySite.Pages.RetireFees.delete()
    assert Enum.map(migrated, & &1.to) == [:deleted, :deleted, :deleted]
    assert types(Pages.page_for("/about")) == [:hero]
    assert types(Pages.page_for(nil)) == []
  end
end
