defmodule Billboard.SectionTest do
  # Not async: a few tests commit, which refreshes the pages cache, and
  # one changes the shop's offers.
  use Billboard.Test.DataCase, async: false

  alias Billboard.Test.Shop

  @opts [authorize?: false]
  @text %{body: "Words"}
  @band %{heading: "Visit"}
  @cards %{items: [%{title: "A basket"}]}

  setup :preserve_cache

  test "sections keep their order, and a new one goes last" do
    version = version_fixture(path: "/about")
    hero = section_fixture(version, :hero, %{heading: "About"})
    second = section_fixture(version, :hero, %{heading: "Another"})

    assert [hero.id, second.id] ==
             Shop.Pages.get_version!(version.id, @opts ++ [load: [:sections]]).sections
             |> Enum.map(& &1.id)

    assert second.position == hero.position + 1
  end

  test "content round-trips as a typed component" do
    section = section_fixture(version_fixture(path: "/about"), :hero, %{heading: "About"})

    assert %Ash.Union{type: :hero, value: %Billboard.Components.Hero{heading: "About"}} =
             Shop.Pages.get_section!(section.id, @opts).content
  end

  test "content built with Billboard.Component.build!/2 is created as it was built" do
    hero = Billboard.Component.build!(:hero, %{heading: "Built"})
    section = section_fixture(version_fixture(path: "/about"), :hero, hero)

    assert %{heading: "Built"} = Shop.Pages.get_section!(section.id, @opts).content.value
  end

  test "content is validated by its component" do
    version = version_fixture(path: "/about")

    assert_raise Ash.Error.Invalid, ~r/add a heading/, fn ->
      section_fixture(version, :hero, %{})
    end
  end

  test "a section's key survives an update" do
    section = section_fixture(version_fixture(path: "/about"), :hero, %{heading: "About"})
    assert is_binary(section.key) and byte_size(section.key) > 0

    updated = Shop.Pages.update_section!(section, %{anchor: "about"}, @opts)

    assert updated.key == section.key
  end

  test "positions count from zero in each version, and under each parent" do
    first = version_fixture(path: "/about")
    other = version_fixture(path: "/")

    parent = section_fixture(first, :columns, %{})
    section_fixture(first, :hero, %{heading: "Another"})
    child = section_fixture(first, :text, @text, parent_id: parent.id)
    elsewhere = section_fixture(other, :hero, %{heading: "Home"})

    assert parent.position == 0
    assert child.position == 0
    assert elsewhere.position == 0
  end

  describe "anchors" do
    test "are unique within a version" do
      version = version_fixture(path: "/about")
      section_fixture(version, :hero, %{heading: "About"}, anchor: "visit")

      assert_raise Ash.Error.Invalid, ~r/another section on this page is “visit”/, fn ->
        section_fixture(version, :hero, %{heading: "Again"}, anchor: "visit")
      end
    end

    test "may repeat across versions, and may be left out" do
      version = version_fixture(path: "/about")
      section_fixture(version, :hero, %{heading: "About"}, anchor: "visit")
      section_fixture(version, :hero, %{heading: "No anchor"})
      section_fixture(version, :hero, %{heading: "No anchor either"})

      other =
        section_fixture(version_fixture(path: "/"), :hero, %{heading: "Home"}, anchor: "visit")

      assert other.anchor == "visit"
    end

    test "can't take an id the site gives something else" do
      version = version_fixture(path: "/about")

      for anchor <- ~w(shop-header item-3 photos-more main page-hero section-hero
                       reviews-show-all) do
        assert_raise Ash.Error.Invalid, ~r/the site already uses/, fn ->
          section_fixture(version, :hero, %{heading: "Taken"}, anchor: anchor)
        end
      end
    end

    test "can't take an id the page editor gives something" do
      version = version_fixture(path: "/about")

      for anchor <- ~w(edit-canvas editor-bar page-issues page-picker draft-status
                       commit-changes discard-changes mode-edit mode-view edit-story
                       open-story words-story-heading) do
        assert_raise Ash.Error.Invalid, ~r/the site already uses/, fn ->
          section_fixture(version, :hero, %{heading: "Taken"}, anchor: anchor)
        end
      end

      assert section_fixture(version, :hero, %{heading: "Free"}, anchor: "editorial").anchor ==
               "editorial"
    end

    test "can take the id its own component gives it, and the same words elsewhere" do
      version = version_fixture(path: "/")

      assert section_fixture(version, :cards, @cards, anchor: "basket").anchor == "basket"
      assert section_fixture(version, :hero, %{heading: "Hi"}, anchor: "item").anchor

      assert_raise Ash.Error.Invalid, ~r/the site already uses/, fn ->
        section_fixture(version, :text, @text, anchor: "basket")
      end
    end

    test "are checked when they change, too" do
      section = section_fixture(version_fixture(path: "/about"), :hero, %{heading: "About"})

      assert {:error, %Ash.Error.Invalid{} = error} =
               Shop.Pages.update_section(section, %{anchor: "main"}, @opts)

      assert Exception.message(error) =~ "the site already uses"
    end
  end

  describe "surfaces" do
    test "a section takes a surface its kind is offered" do
      version = version_fixture(path: "/about")

      assert %{surface: "plain"} = section_fixture(version, :text, @text, surface: "plain")
      assert %{surface: "loud"} = section_fixture(version, :band, @band, surface: "loud")
    end

    test "a section refuses a surface its kind isn't offered" do
      version = version_fixture(path: "/about")

      assert_raise Ash.Error.Invalid, ~r/isn't a surface this section can take/, fn ->
        section_fixture(version, :text, @text, surface: "loud")
      end

      assert_raise Ash.Error.Invalid, ~r/isn't a surface this section can take/, fn ->
        section_fixture(version, :band, @band, surface: "lilac")
      end
    end

    test "a section takes no surface, meaning its kind's default" do
      section = section_fixture(version_fixture(path: "/about"), :text, @text)
      assert section.surface == nil
    end

    test "is checked when it changes, too" do
      section = section_fixture(version_fixture(path: "/about"), :band, @band)

      assert {:error, error} = Shop.Pages.update_section(section, %{surface: "plain"}, @opts)
      assert Exception.message(error) =~ "isn't a surface this section can take"

      assert {:ok, %{surface: "loud"}} =
               Shop.Pages.update_section(section, %{surface: "loud"}, @opts)
    end

    test "a section that takes its surface from elsewhere refuses one of its own" do
      draft = version_fixture(path: "/about")
      hero = section_fixture(draft, :hero, %{heading: "About"})
      columns = section_fixture(draft, :columns, %{})
      left = section_fixture(draft, :text, @text, parent_id: columns.id)

      assert {:error, error} = Shop.Pages.update_section(hero, %{surface: "plain"}, @opts)
      assert Exception.message(error) =~ "the hero takes its surface from the page's header"

      assert {:error, error} = Shop.Pages.update_section(left, %{surface: "plain"}, @opts)
      assert Exception.message(error) =~ "a column takes its surface from its Two columns"

      assert_raise Ash.Error.Invalid, ~r/takes its surface from its library section/, fn ->
        section_fixture(draft, :shared, %{key: Ecto.UUID.generate()}, surface: "plain")
      end
    end

    test "a section that takes its surface from elsewhere still takes none" do
      draft = version_fixture(path: "/about")
      hero = section_fixture(draft, :hero, %{heading: "About"})
      columns = section_fixture(draft, :columns, %{})
      left = section_fixture(draft, :text, @text, parent_id: columns.id)

      assert {:ok, %{surface: nil}} = Shop.Pages.update_section(hero, %{surface: nil}, @opts)
      assert {:ok, %{surface: nil}} = Shop.Pages.update_section(left, %{surface: nil}, @opts)

      assert %{surface: nil} =
               section_fixture(draft, :shared, %{key: Ecto.UUID.generate()}, surface: nil)
    end

    test "a surface the site no longer offers stays, until it changes" do
      version = version_fixture(path: "/about")
      section = seed_section_fixture(version, :text, @text, surface: "lilac", position: 0)

      assert {:ok, %{surface: "lilac"}} =
               Shop.Pages.update_section(
                 section,
                 %{content: %Ash.Union{type: :text, value: %{body: "Other words"}}},
                 @opts
               )

      assert {:ok, %{surface: "lilac"}} =
               Shop.Pages.update_section(section, %{surface: "lilac"}, @opts)

      assert {:error, error} = Shop.Pages.update_section(section, %{surface: "loud"}, @opts)
      assert Exception.message(error) =~ "“loud” isn't a surface this section can take"
    end

    test "survives an edit and a publish" do
      {:ok, draft} = Shop.Pages.edit_page("/", @opts)
      section = section_fixture(draft, :text, @text, surface: "plain")

      {:ok, live} = Shop.Pages.commit_page("/", @opts)
      assert by_key(live, section.key).surface == "plain"

      {:ok, next} = Shop.Pages.edit_page("/", @opts)
      assert by_key(next, section.key).surface == "plain"
    end

    test "a Two columns section's surface survives an edit, and its columns copy too" do
      {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      [_hero, columns] = load(draft).sections
      Shop.Pages.update_section!(columns, %{surface: "plain"}, @opts)

      {:ok, _live} = Shop.Pages.commit_page("/about", @opts)
      {:ok, next} = Shop.Pages.edit_page("/about", @opts)

      assert [_hero, %{key: key, surface: "plain"} = columns] = load(next).sections
      assert [%{surface: nil}, %{surface: nil}] = columns.children
      assert key == by_key(draft, key).key
    end

    test "a live surface the site no longer offers still makes a draft" do
      {:ok, page} = Shop.Pages.ensure_page("/about", @opts)
      live = Ash.Seed.seed!(Shop.Version, %{page_id: page.id, status: :live})
      hero = seed_section_fixture(live, :hero, %{heading: "About"}, position: 0)
      text = seed_section_fixture(live, :text, @text, surface: "lilac", position: 1)

      assert {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      assert by_key(draft, hero.key).surface == nil
      assert by_key(draft, text.key).surface == "lilac"
    end

    test "a live section holding settings the site no longer offers still makes a draft, keeping them" do
      {:ok, page} = Shop.Pages.ensure_page("/about", @opts)
      live = Ash.Seed.seed!(Shop.Version, %{page_id: page.id, status: :live})
      seed_section_fixture(live, :hero, %{heading: "About"}, position: 0)

      # Saved while the shop offered cards, four items, and card surfaces,
      # then narrowed.
      put_shop!(options: [cards: [look: [:cards, :rows]]], offered: [card: ["plain", "loud"]])

      four = [
        %{title: "Assess", surface: "loud"},
        %{title: "Treat", surface: "plain"},
        %{title: "Review", surface: "loud"},
        %{title: "Rest"}
      ]

      cards = seed_section_fixture(live, :cards, %{look: :cards, items: four}, position: 1)
      put_shop!(options: [cards: [look: [:rows], items: 1..3]], offered: [card: []])

      assert {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      copy = by_key(draft, cards.key).content.value

      assert %{look: :cards} = copy
      assert Enum.map(copy.items, & &1.surface) == ["loud", "plain", "loud", nil]
    end

    test "is checked again when the content's type changes" do
      version = version_fixture(path: "/about")
      section = section_fixture(version, :text, @text, surface: "plain")

      assert {:error, error} =
               Shop.Pages.update_section(
                 section,
                 %{content: %Ash.Union{type: :band, value: @band}},
                 @opts
               )

      assert Exception.message(error) =~ "“plain” isn't a surface this section can take"
    end
  end

  describe "placing a section inside another" do
    setup do
      %{version: version_fixture(path: "/about")}
    end

    test "works inside a Two columns section on the same version", %{version: version} do
      columns = section_fixture(version, :columns, %{})
      child = section_fixture(version, :text, @text, parent_id: columns.id)

      assert child.parent_id == columns.id
    end

    test "refuses a parent on another version", %{version: version} do
      columns = section_fixture(version_fixture(path: "/"), :columns, %{})

      assert_raise Ash.Error.Invalid, ~r/inside a section on the same page/, fn ->
        section_fixture(version, :text, @text, parent_id: columns.id)
      end
    end

    test "refuses a parent that isn't Two columns", %{version: version} do
      hero = section_fixture(version, :hero, %{heading: "About"})

      assert_raise Ash.Error.Invalid, ~r/only inside Two columns/, fn ->
        section_fixture(version, :text, @text, parent_id: hero.id)
      end
    end

    test "goes only one level deep", %{version: version} do
      outer = section_fixture(version, :columns, %{})
      inner = section_fixture(version, :columns, %{}, parent_id: outer.id)

      assert_raise Ash.Error.Invalid, ~r/one level deep/, fn ->
        section_fixture(version, :text, @text, parent_id: inner.id)
      end
    end
  end

  describe "removing" do
    test "a hero can't be removed" do
      hero = section_fixture(version_fixture(path: "/about"), :hero, %{heading: "About"})

      assert {:error, error} = Shop.Pages.destroy_section(hero, @opts)
      assert Exception.message(error) =~ "every page keeps its hero"
    end

    test "a fixed page's sections can't be removed" do
      version = version_fixture(path: "/terms")
      section_fixture(version, :hero, %{heading: "Terms"})
      terms = section_fixture(version, :text, %{body: "Be kind."})

      assert {:error, error} = Shop.Pages.destroy_section(terms, @opts)
      assert Exception.message(error) =~ "this page's sections are fixed"
    end

    test "any other section can, with its children" do
      version = version_fixture(path: "/about")
      section_fixture(version, :hero, %{heading: "About"})
      columns = section_fixture(version, :columns, %{})
      left = section_fixture(version, :text, @text, parent_id: columns.id)

      assert :ok = Shop.Pages.destroy_section(columns, @opts)
      assert [:hero] = types(version)

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Shop.Pages.get_section(left.id, @opts)
    end
  end

  describe "the live version" do
    setup do
      {:ok, page} = Shop.Pages.ensure_page("/about", @opts)
      live = Ash.Seed.seed!(Shop.Version, %{page_id: page.id, status: :live})
      hero = seed_section_fixture(live, :hero, %{heading: "About"}, position: 0)
      columns = seed_section_fixture(live, :columns, %{}, position: 1)
      %{live: live, hero: hero, columns: columns}
    end

    test "can't be edited directly", %{hero: hero} do
      assert {:error, error} =
               Shop.Pages.update_section(
                 hero,
                 %{content: %Ash.Union{type: :hero, value: %{heading: "x"}}},
                 @opts
               )

      assert Exception.message(error) =~ "edit the page's draft, not its live layout"
    end

    test "can't gain or lose sections", %{live: live, columns: columns} do
      assert_raise Ash.Error.Invalid, ~r/edit the page's draft/, fn ->
        section_fixture(live, :text, @text)
      end

      assert {:error, error} = Shop.Pages.destroy_section(columns, @opts)
      assert Exception.message(error) =~ "edit the page's draft, not its live layout"

      assert {:error, error} =
               Shop.Section
               |> Ash.Changeset.for_create(
                 :copy,
                 %{version_id: live.id, content: %Ash.Union{type: :band, value: %{heading: "x"}}},
                 @opts
               )
               |> Ash.create()

      assert Exception.message(error) =~ "edit the page's draft, not its live layout"
    end
  end

  defp load(v), do: Shop.Pages.get_version!(v.id, @opts ++ [load: [sections: :children]])
  defp by_key(v, key), do: Enum.find(load(v).sections, &(&1.key == key))

  defp types(version) do
    Shop.Pages.get_version!(version.id, @opts ++ [load: [:sections]]).sections
    |> Enum.map(& &1.content.type)
  end
end
