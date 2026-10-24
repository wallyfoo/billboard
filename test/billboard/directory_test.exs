defmodule Billboard.DirectoryTest do
  @moduledoc "The pages the builder knows, from the site's `pages` section."
  # It names the site in application env, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Directory
  alias Billboard.Directory.Page

  defmodule NoHomeSite do
    @moduledoc "A site whose pages have no `/`."
    def pages,
      do: [
        %Page{pattern: nil, label: "Shared sections", kind: :library},
        %Page{pattern: "/about", label: "About", kind: :free},
        %Page{pattern: "/terms", label: "Terms", kind: :free}
      ]
  end

  defmodule LibraryOnlySite do
    @moduledoc "A site whose only page is the library."
    def pages, do: [%Page{pattern: nil, label: "Shared sections", kind: :library}]
  end

  setup do
    put_env_for_test(:billboard, :site, Billboard.Test.PlainSite)
  end

  test "lists the site's pages, the library last" do
    assert Enum.map(Directory.pages(), & &1.pattern) == ["/", "/terms", nil]
  end

  test "fetch/1 finds a page by pattern, and the library by nil" do
    assert Directory.fetch("/terms").fixed == [:note]
    assert Directory.fetch(nil).kind == :library
    assert Directory.fetch("/nowhere") == nil
  end

  test "fetch!/1 raises for an unknown page" do
    assert_raise ArgumentError, ~r/no builder page for "\/nowhere"/, fn ->
      Directory.fetch!("/nowhere")
    end
  end

  test "home!/0 is the `/` page" do
    assert Directory.home!().pattern == "/"
  end

  test "home!/0 is the first page that isn't the library, on a site with no `/`" do
    put_env_for_test(:billboard, :site, NoHomeSite)

    assert Directory.home!().pattern == "/about"
  end

  test "home!/0 names the fix on a site whose only page is the library" do
    put_env_for_test(:billboard, :site, LibraryOnlySite)

    assert_raise ArgumentError,
                 ~r/LibraryOnlySite has no page for the editor to open. Declare `page "\/", …` in the site's `pages do`/,
                 fn ->
                   Directory.home!()
                 end
  end

  test "fixed?/1 is true only for a page with fixed sections" do
    assert Directory.fixed?("/terms")
    refute Directory.fixed?("/")
    refute Directory.fixed?(nil)
    refute Directory.fixed?("/nowhere")
  end

  test "a site that isn't a `use Billboard.Site` module says how to give it pages" do
    put_env_for_test(:billboard, :site, Billboard.Test.Site)

    assert_raise ArgumentError, ~r/doesn't define pages\/0. Give it `use Billboard.Site`/, fn ->
      Directory.pages()
    end
  end
end
