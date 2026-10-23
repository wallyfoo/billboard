defmodule Billboard.PagesTest do
  use Billboard.Test.DataCase, async: false

  alias Billboard.Test.Shop

  @opts [authorize?: false]
  @text %{body: "Words"}

  setup :preserve_cache

  describe "changing a draft" do
    test "makes the draft, and returns what the change returns" do
      assert {:ok, "hero"} =
               Shop.Pages.change_draft(
                 "/",
                 fn _draft, sections ->
                   {:ok, sections["hero"].key}
                 end,
                 actor: admin()
               )

      assert {:ok, %Shop.Version{}} = Shop.Pages.draft_for("/", @opts)
    end

    test "a change turned down hands back its own reason, and leaves no draft" do
      assert {:error, :gone} =
               Shop.Pages.change_draft("/", fn _draft, _sections -> {:error, :gone} end,
                 actor: admin()
               )

      assert {:ok, nil} = Shop.Pages.draft_for("/", @opts)
    end
  end

  describe "a first edit's clash" do
    test "is on one of the unique indexes of the site's tables, and is tried again" do
      clash = &%Ash.Error.Invalid{errors: [%{private_vars: [constraint: &1]}]}

      assert Billboard.Pages.first_edit_clash?(
               clash.("billboard_versions_one_draft_per_page_index")
             )

      assert Billboard.Pages.first_edit_clash?(clash.("billboard_pages_unique_pattern_index"))
      assert Billboard.Pages.first_edit_clash?(clash.("billboard_pages_one_library_index"))
      refute Billboard.Pages.first_edit_clash?(clash.("billboard_sections_unique_key_index"))
    end
  end

  describe "editing a page" do
    test "the first edit copies the starter into a draft" do
      assert {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      assert draft.status == :draft
      assert [:hero, :columns] = types(draft)
    end

    test "copies the live version when there is one, keeping keys" do
      {:ok, live} = commit!("/")
      assert {:ok, draft} = Shop.Pages.edit_page("/", @opts)

      assert draft.id != live.id
      assert keys(draft) == keys(live)
    end

    test "copies the children of two columns" do
      {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      assert [_left, _right] = Enum.at(load(draft).sections, 1).children
    end

    test "returns the draft with its sections and their children, every time" do
      for _call <- 1..2 do
        assert {:ok, %{sections: [_hero, %{children: [_left, _right]}]}} =
                 Shop.Pages.edit_page("/about", @opts)
      end
    end

    test "leaves no draft when copying the live version fails" do
      {:ok, page} = Shop.Pages.ensure_page("/about", @opts)
      live = Ash.Seed.seed!(Shop.Version, %{page_id: page.id, status: :live})
      hero = seed_section_fixture(live, :hero, %{heading: "About"}, position: 0)
      # Only Two columns may hold a section, so this one can't be copied.
      seed_section_fixture(live, :hero, %{heading: "Inside"}, parent_id: hero.id)

      assert {:error, _error} = Shop.Pages.edit_page("/about", @opts)
      assert {:ok, nil} = Shop.Pages.draft_for("/about", @opts)
    end

    test "keeps the ids of a section's parts through commit and the next edit" do
      {:ok, draft} = Shop.Pages.edit_page("/", @opts)

      section_fixture(draft, :cards, %{
        head: %{title: "Ask"},
        items: [%{title: "Book"}, %{title: "Visit"}]
      })

      {:ok, live} = Shop.Pages.commit_page("/", @opts)
      {:ok, next} = Shop.Pages.edit_page("/", @opts)

      before = List.last(load(live).sections)
      now = List.last(load(next).sections)

      assert now.key == before.key
      assert now.id != before.id
      assert item_ids(now) == item_ids(before)
    end

    test "the first edit keeps the ids of the starter's parts" do
      starter = Shop.Starter.version("/")
      {:ok, draft} = Shop.Pages.edit_page("/", @opts)

      for {from, to} <- Enum.zip(starter.sections, load(draft).sections),
          from.content.type == :hero do
        assert action_ids(to) == action_ids(from)
        assert action_ids(to) == [Shop.Starter.shop_now()]
      end
    end

    test "returns the same draft until it is committed or discarded" do
      {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      assert {:ok, %{id: id}} = Shop.Pages.edit_page("/about", @opts)
      assert id == draft.id
      assert {:ok, %{id: ^id}} = Shop.Pages.draft_for("/about", @opts)
    end

    test "makes the page's record on its first edit" do
      assert {:ok, nil} = Shop.Pages.fetch_page("/", @opts)
      assert {:ok, _draft} = Shop.Pages.edit_page("/", @opts)
      assert {:ok, %{pattern: "/"}} = Shop.Pages.fetch_page("/", @opts)
    end

    test "edits the shared sections on the library page" do
      assert {:ok, draft} = Shop.Pages.edit_page(nil, @opts)
      assert {:ok, %{id: id, pattern: nil}} = Shop.Pages.fetch_library_page(@opts)
      assert draft.page_id == id
    end

    test "refuses a page the builder doesn't know" do
      assert {:error, error} = Shop.Pages.edit_page("/offers", @opts)
      assert Exception.message(error) =~ "there is no such page"
    end

    test "needs a signed-in user" do
      assert {:error, %Ash.Error.Forbidden{}} = Shop.Pages.edit_page("/about")
      assert {:ok, _draft} = Shop.Pages.edit_page("/about", actor: admin())
    end

    test "with no draft, draft_for creates nothing" do
      assert {:ok, nil} = Shop.Pages.draft_for("/offers", @opts)
      assert {:ok, nil} = Shop.Pages.fetch_page("/offers", @opts)
    end
  end

  describe "without a signed-in user" do
    test "committing, discarding, and arranging are forbidden" do
      {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      ids = Enum.map(draft.sections, & &1.id)

      assert {:error, %Ash.Error.Forbidden{}} = Shop.Pages.commit_page("/about")
      assert {:error, %Ash.Error.Forbidden{}} = Shop.Pages.discard_page("/about")
      assert {:error, %Ash.Error.Forbidden{}} = Shop.Pages.arrange_sections(draft.id, ids)
      assert {:ok, %{id: id}} = Shop.Pages.draft_for("/about", @opts)
      assert id == draft.id
    end
  end

  describe "committing" do
    test "makes the draft live and deletes the old live version" do
      {:ok, old} = commit!("/")
      {:ok, draft} = Shop.Pages.edit_page("/", @opts)

      assert {:ok, live} = Shop.Pages.commit_page("/", @opts)
      assert live.id == draft.id
      assert live.status == :live
      assert %DateTime{} = live.committed_at
      assert {:error, _} = Shop.Pages.get_version(old.id, @opts)
      assert {:ok, nil} = Shop.Pages.draft_for("/", @opts)
    end

    test "refuses a draft that breaks the rules, says why, and keeps the draft" do
      {:ok, draft} = Shop.Pages.edit_page("/", @opts)
      section_fixture(draft, :hero, %{heading: "Another hero"})

      assert {:error, error} = Shop.Pages.commit_page("/", @opts)
      assert Exception.message(error) =~ "a page has one hero"
      assert {:ok, %{id: id}} = Shop.Pages.draft_for("/", @opts)
      assert id == draft.id
    end

    test "with no draft, says there is nothing to commit" do
      assert {:error, error} = Shop.Pages.commit_page("/", @opts)
      assert Exception.message(error) =~ "no changes to commit"
    end
  end

  describe "discarding" do
    test "deletes the draft and leaves the live version alone" do
      {:ok, live} = commit!("/")
      {:ok, _draft} = Shop.Pages.edit_page("/", @opts)

      assert :ok = Shop.Pages.discard_page("/", @opts)
      assert {:ok, nil} = Shop.Pages.draft_for("/", @opts)
      assert {:ok, %{status: :live}} = Shop.Pages.get_version(live.id, @opts)
    end

    test "with no draft, does nothing" do
      assert :ok = Shop.Pages.discard_page("/", @opts)
    end
  end

  describe "arranging" do
    test "reorders the top-level sections" do
      {:ok, v} = Shop.Pages.edit_page("/", @opts)
      section_fixture(v, :text, @text)
      [hero | rest] = load(v).sections
      order = [hero.id | Enum.reverse(Enum.map(rest, & &1.id))]

      assert :ok = Shop.Pages.arrange_sections(v.id, order, @opts)
      assert Enum.map(load(v).sections, & &1.id) == order
    end

    test "keeps the hero first" do
      {:ok, v} = Shop.Pages.edit_page("/", @opts)
      [hero, next | rest] = Enum.map(load(v).sections, & &1.id)

      assert {:error, error} = Shop.Pages.arrange_sections(v.id, [next, hero | rest], @opts)
      assert Exception.message(error) =~ "hero stays first"
    end

    test "must list every section exactly once" do
      {:ok, v} = Shop.Pages.edit_page("/", @opts)
      [hero | _rest] = Enum.map(load(v).sections, & &1.id)

      assert {:error, error} = Shop.Pages.arrange_sections(v.id, [hero, hero], @opts)
      assert Exception.message(error) =~ "every section exactly once"
    end

    test "refuses to move a fixed page's sections" do
      {:ok, v} = Shop.Pages.edit_page("/terms", @opts)
      ids = Enum.map(load(v).sections, & &1.id)

      assert {:error, error} = Shop.Pages.arrange_sections(v.id, Enum.reverse(ids), @opts)
      assert Exception.message(error) =~ "fixed"
    end

    test "leaves the live version alone" do
      {:ok, draft} = Shop.Pages.edit_page("/", @opts)
      section_fixture(draft, :text, @text)
      {:ok, live} = Shop.Pages.commit_page("/", @opts)
      section_ids = Enum.map(load(live).sections, & &1.id)
      [hero | rest] = section_ids
      order = [hero | Enum.reverse(rest)]

      assert {:error, error} = Shop.Pages.arrange_sections(live.id, order, @opts)
      assert Exception.message(error) =~ "edit the page's draft, not its live layout"
      assert Enum.map(load(live).sections, & &1.id) == section_ids
    end
  end

  describe "swapping columns" do
    defp columns_fixture(version) do
      columns = section_fixture(version, :columns, %{})
      left = section_fixture(version, :text, @text, parent_id: columns.id)
      right = section_fixture(version, :text, @text, parent_id: columns.id)
      {Shop.Pages.get_section!(columns.id, @opts ++ [load: [:children]]), left, right}
    end

    test "puts the right column on the left, and the left on the right" do
      {:ok, v} = Shop.Pages.edit_page("/", @opts)
      {columns, left, right} = columns_fixture(v)

      assert :ok = Shop.Pages.swap_columns(columns, @opts)

      assert Enum.map(
               Shop.Pages.get_section!(columns.id, @opts ++ [load: [:children]]).children,
               & &1.id
             ) ==
               [right.id, left.id]
    end

    test "refuses a section that isn't Two columns" do
      {:ok, v} = Shop.Pages.edit_page("/", @opts)

      assert {:error, error} = Shop.Pages.swap_columns(hd(load(v).sections), @opts)
      assert Exception.message(error) =~ "only Two columns"
    end

    test "refuses on a fixed page" do
      {:ok, v} = Shop.Pages.edit_page("/terms", @opts)
      {columns, left, right} = columns_fixture(v)

      assert {:error, error} = Shop.Pages.swap_columns(columns, @opts)
      assert Exception.message(error) =~ "fixed"

      assert Enum.map(
               Shop.Pages.get_section!(columns.id, @opts ++ [load: [:children]]).children,
               & &1.id
             ) ==
               [left.id, right.id]
    end
  end

  defp load(v), do: Shop.Pages.get_version!(v.id, @opts ++ [load: [sections: :children]])
  defp keys(v), do: Enum.map(load(v).sections, & &1.key)
  defp types(v), do: Enum.map(load(v).sections, & &1.content.type)

  defp item_ids(%{content: %{value: value}}), do: Enum.map(value.items, & &1.id)

  # A hero's actions.
  defp action_ids(%{content: %{value: value}}), do: Enum.map(value.actions, & &1.id)

  defp commit!(pattern) do
    {:ok, _draft} = Shop.Pages.edit_page(pattern, @opts)
    Shop.Pages.commit_page(pattern, @opts)
  end
end
