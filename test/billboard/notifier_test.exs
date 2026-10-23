defmodule Billboard.NotifierTest do
  use Billboard.Test.DataCase, async: false

  alias Billboard.Test.Shop

  @opts [authorize?: false]

  setup :preserve_cache

  test "a change to a draft's section tells the page's editors, and leaves the cache alone" do
    version = version_fixture(path: "/about")
    Shop.Pages.subscribe_page("/about")
    Shop.Pages.subscribe()

    section_fixture(version, :text, %{body: "Come in."})

    assert_receive {:page_draft_changed, "/about"}
    refute_receive {:pages_updated, _, _}
  end

  test "the library's editors have a topic of their own" do
    version = version_fixture(path: nil)
    Shop.Pages.subscribe_page(nil)
    Shop.Pages.subscribe_page("/about")

    section_fixture(version, :band, %{heading: "Visit"})

    assert_receive {:page_draft_changed, nil}
    refute_receive {:page_draft_changed, "/about"}
  end

  test "making a version live refreshes the cache, and tells the page's editors" do
    draft = version_fixture(path: "/about")
    Shop.Pages.subscribe_page("/about")
    Shop.Pages.subscribe()

    Ash.update!(draft, %{}, action: :make_live, authorize?: false)

    assert_receive {:page_draft_changed, "/about"}
    assert_receive {:pages_updated, _, snapshot}
    assert snapshot.pages["/about"].id == draft.id
    assert Billboard.Cache.snapshot().pages["/about"].id == draft.id
  end

  test "a notification for a record that has gone is nothing" do
    draft = version_fixture(path: "/about")
    section = section_fixture(draft, :text, %{body: "Come in."})
    Shop.Pages.destroy_section!(section, @opts)
    Ash.destroy!(draft, @opts)
    Shop.Pages.subscribe_page("/about")
    Shop.Pages.subscribe()

    assert :ok =
             Billboard.Notifier.notify(%Ash.Notifier.Notification{
               resource: Shop.Section,
               action: Ash.Resource.Info.action(Shop.Section, :create),
               data: section
             })

    refute_receive _
  end

  test "on a site's own resource, it logs that the cache notifier belongs there instead" do
    log =
      ExUnit.CaptureLog.capture_log(fn ->
        assert :ok =
                 Billboard.Notifier.notify(%Ash.Notifier.Notification{
                   resource: Billboard.Test.Cards,
                   action: Ash.Resource.Info.action(Billboard.Test.Cards, :create),
                   data: %Billboard.Test.Cards{}
                 })
      end)

    assert log =~ "Billboard.Notifier is on Billboard.Test.Cards"
    assert log =~ "use `simple_notifiers: [Billboard.CacheNotifier]` on it instead"
    assert :ets.lookup(Billboard.Cache, :snapshot) == []
  end

  test "page_topic/1 gives the library and each page a topic" do
    assert Shop.Pages.page_topic(nil) == "pages:shared"
    assert Shop.Pages.page_topic("/about") == "pages:page:/about"
  end
end
