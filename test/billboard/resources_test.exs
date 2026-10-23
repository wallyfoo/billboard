defmodule Billboard.ResourcesTest do
  @moduledoc "What `use Billboard.Page`, `Version`, and the rest check as they compile."
  use ExUnit.Case, async: true

  import Spark.Test

  alias Billboard.Test.Shop

  describe "a resource's use" do
    test "without its site doesn't compile, and shows one" do
      assert_raise ArgumentError, ~r/needs its site, such as `site: MySite.Billboard`/, fn ->
        Code.compile_string("""
        defmodule Billboard.ResourcesTest.NoSite do
          use Billboard.Version
        end
        """)
      end
    end

    test "naming a module that isn't a site doesn't compile, and says to make it one" do
      assert_raise ArgumentError,
                   ~r/names Billboard.Test.Cards as its site, which doesn't `use Billboard.Site`.*add `use Billboard.Site` to it/,
                   fn ->
                     Code.compile_string("""
                     defmodule Billboard.ResourcesTest.NotASite do
                       use Billboard.Version, site: Billboard.Test.Cards
                     end
                     """)
                   end
    end

    test "that the site doesn't name doesn't compile, and says to name it" do
      assert_raise ArgumentError,
                   ~r/names Billboard.Test.Shop.Version as its version, not Billboard.ResourcesTest.Stray. Add `version: Billboard.ResourcesTest.Stray` to the `resources:`/,
                   fn ->
                     Code.compile_string("""
                     defmodule Billboard.ResourcesTest.Stray do
                       use Billboard.Version, site: Billboard.Test.Shop
                     end
                     """)
                   end
    end

    test "on a site with no domain doesn't compile, and says to add one" do
      assert_raise ArgumentError,
                   ~r/names no domain, which its pages' resources need. Add `domain: MySite.Pages`/,
                   fn ->
                     Code.compile_string("""
                     defmodule Billboard.ResourcesTest.NoDomainSite do
                       use Billboard.Site,
                         otp_app: :billboard,
                         repo: Billboard.Test.Repo,
                         resources: [page: Billboard.ResourcesTest.NoDomainPage]
                     end

                     defmodule Billboard.ResourcesTest.NoDomainPage do
                       use Billboard.Page, site: Billboard.ResourcesTest.NoDomainSite
                     end
                     """)
                   end
    end

    test "on a site with no repo doesn't compile, and says to add one" do
      assert_raise ArgumentError,
                   ~r/names no repo, which its pages' resources need. Add `repo: MySite.Repo`/,
                   fn ->
                     Code.compile_string("""
                     defmodule Billboard.ResourcesTest.NoRepoSite do
                       use Billboard.Site,
                         otp_app: :billboard,
                         domain: Billboard.Test.Shop.Pages,
                         resources: [page: Billboard.ResourcesTest.NoRepoPage]
                     end

                     defmodule Billboard.ResourcesTest.NoRepoPage do
                       use Billboard.Page, site: Billboard.ResourcesTest.NoRepoSite
                     end
                     """)
                   end
    end

    test "with an option it doesn't take doesn't compile, and names the ones it does" do
      assert_raise ArgumentError,
                   ~r/`use Billboard.Page` takes `site:` and `table:`, not :tabel/,
                   fn ->
                     Code.compile_string("""
                     defmodule Billboard.ResourcesTest.Typo do
                       use Billboard.Page, site: Billboard.Test.Shop, tabel: "pages"
                     end
                     """)
                   end
    end
  end

  test "a content union of a site listing a module that isn't a component doesn't compile" do
    assert_raise ArgumentError,
                 ~r/lists Billboard.Test.Plain in `components:`, which isn't a billboard component/,
                 fn ->
                   Code.compile_string("""
                   defmodule Billboard.ResourcesTest.PlainSite do
                     use Billboard.Site,
                       otp_app: :billboard,
                       components: [Billboard.Test.Plain],
                       resources: [content: Billboard.ResourcesTest.PlainContent]
                   end

                   defmodule Billboard.ResourcesTest.PlainContent do
                     use Billboard.Content, site: Billboard.ResourcesTest.PlainSite
                   end
                   """)
                 end
  end

  test "each resource knows its kind" do
    assert Billboard.Resource.kind(Shop.Page) == :page
    assert Billboard.Resource.kind(Shop.Version) == :version
    assert Billboard.Resource.kind(Shop.Section) == :section
    assert Billboard.Resource.kind(Billboard.Test.Cards) == nil
  end

  test "a site naming a resource of another kind fails its check" do
    errors =
      dsl_errors do
        defmodule Elixir.Billboard.ResourcesTest.WrongKind do
          use Billboard.Site,
            otp_app: :billboard,
            resources: [version: Billboard.Test.Shop.Page]
        end
      end

    assert [{_, [error]}] = errors

    assert error.message =~
             "Billboard.ResourcesTest.WrongKind names Billboard.Test.Shop.Page as its version " <>
               "resource, but it doesn't `use Billboard.Version`."
  end
end
