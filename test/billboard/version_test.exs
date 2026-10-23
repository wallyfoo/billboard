defmodule Billboard.VersionTest do
  use Billboard.Test.DataCase, async: true

  alias Billboard.Test.Shop

  @opts [authorize?: false]

  test "a version belongs to a page and starts as a draft" do
    version = version_fixture(path: "/about")

    assert version.status == :draft
    assert Ash.load!(version, :page, @opts).page.pattern == "/about"
  end

  test "a page has at most one draft" do
    version_fixture(path: "/about")
    assert_raise Ash.Error.Invalid, fn -> version_fixture(path: "/about") end
  end

  describe "reading drafts" do
    setup do
      version = version_fixture(path: "/about")
      section = section_fixture(version, :hero, %{heading: "About"})
      %{version: version, section: section}
    end

    test "is hidden from visitors", %{version: version, section: section} do
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Shop.Pages.get_version(version.id)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Shop.Pages.get_section(section.id)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Shop.Pages.get_section_by_key(version.id, section.key)
    end

    test "is open to a signed-in user", %{version: version, section: section} do
      actor = admin()

      assert {:ok, _} = Shop.Pages.get_version(version.id, actor: actor)
      assert {:ok, _} = Shop.Pages.get_section(section.id, actor: actor)
      assert {:ok, _} = Shop.Pages.get_section_by_key(version.id, section.key, actor: actor)
    end

    test "is open when authorization is skipped", %{version: version, section: section} do
      assert {:ok, _} = Shop.Pages.get_version(version.id, @opts)
      assert {:ok, _} = Shop.Pages.get_section(section.id, @opts)
      assert {:ok, _} = Shop.Pages.get_section_by_key(version.id, section.key, @opts)
    end
  end

  test "a live version and its sections are open to visitors" do
    {:ok, library} = Shop.Pages.ensure_page(nil, @opts)
    live = Ash.Seed.seed!(Shop.Version, %{page_id: library.id, status: :live})

    section = seed_section_fixture(live, :band, %{heading: "Live"})

    assert {:ok, _} = Shop.Pages.get_version(live.id)
    assert {:ok, _} = Shop.Pages.get_section(section.id)
  end
end
