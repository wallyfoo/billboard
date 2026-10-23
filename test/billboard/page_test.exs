defmodule Billboard.PageTest do
  use Billboard.Test.DataCase, async: true

  alias Billboard.Test.Shop

  @opts [authorize?: false]

  describe "ensure_page/2" do
    test "makes a page for a pattern once, and finds it after" do
      assert {:ok, nil} = Shop.Pages.fetch_page("/about", @opts)
      assert {:ok, %{id: id, pattern: "/about"}} = Shop.Pages.ensure_page("/about", @opts)
      assert {:ok, %{id: ^id}} = Shop.Pages.ensure_page("/about", @opts)
      assert {:ok, %{id: ^id}} = Shop.Pages.fetch_page("/about", @opts)
    end

    test "makes the library, the page with no pattern, once" do
      assert {:ok, nil} = Shop.Pages.fetch_library_page(@opts)
      assert {:ok, %{id: id, pattern: nil}} = Shop.Pages.ensure_page(nil, @opts)
      assert {:ok, %{id: ^id}} = Shop.Pages.ensure_page(nil, @opts)
      assert {:ok, %{id: ^id}} = Shop.Pages.fetch_library_page(@opts)
    end
  end

  # The engine tries a first edit again when it clashes on one of these
  # constraints, so their names are pinned here.
  describe "a second page with the same pattern" do
    test "is refused by the unique pattern" do
      Shop.Pages.create_page!(%{pattern: "/about"}, @opts)

      assert {:error, error} = Shop.Pages.create_page(%{pattern: "/about"}, @opts)
      assert "billboard_pages_unique_pattern_index" in constraint_names(error)
    end

    test "is refused for the library too" do
      Shop.Pages.create_page!(%{pattern: nil}, @opts)

      assert {:error, error} = Shop.Pages.create_page(%{pattern: nil}, @opts)
      assert "billboard_pages_one_library_index" in constraint_names(error)
    end
  end

  test "anyone may read a page, and only a signed-in user make one" do
    {:ok, _page} = Shop.Pages.ensure_page("/about", @opts)

    assert {:ok, %{pattern: "/about"}} = Shop.Pages.fetch_page("/about")
    assert {:error, %Ash.Error.Forbidden{}} = Shop.Pages.create_page(%{pattern: "/terms"})
    assert {:ok, _page} = Shop.Pages.create_page(%{pattern: "/terms"}, actor: admin())
  end

  defp constraint_names(%{errors: errors}),
    do: for(%{private_vars: vars} when is_list(vars) <- errors, do: vars[:constraint])
end
