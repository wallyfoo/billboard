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

  # Its modules aren't named Page, Version, and Section, as the shop's
  # are, so nothing here can lean on a name Ash derives from a module's.
  test "each resource takes its table, and names its indexes after it" do
    warnings =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule Billboard.ResourcesTest.TabledSite do
          use Billboard.Site,
            otp_app: :billboard,
            repo: Billboard.Test.Repo,
            domain: Billboard.ResourcesTest.TabledPages,
            resources: [
              page: Billboard.ResourcesTest.TabledPage,
              version: Billboard.ResourcesTest.TabledVersion,
              section: Billboard.ResourcesTest.TabledSection,
              content: Billboard.ResourcesTest.TabledContent
            ],
            components: [Billboard.Components.Hero, Billboard.Test.Text]
        end

        defmodule Billboard.ResourcesTest.TabledContent do
          use Billboard.Content, site: Billboard.ResourcesTest.TabledSite
        end

        defmodule Billboard.ResourcesTest.TabledPage do
          use Billboard.Page, site: Billboard.ResourcesTest.TabledSite, table: "site_pages"
        end

        defmodule Billboard.ResourcesTest.TabledVersion do
          use Billboard.Version, site: Billboard.ResourcesTest.TabledSite, table: "page_versions"
        end

        defmodule Billboard.ResourcesTest.TabledSection do
          use Billboard.Section, site: Billboard.ResourcesTest.TabledSite, table: "page_sections"
        end

        defmodule Billboard.ResourcesTest.TabledPages do
          use Billboard.Domain,
            site: Billboard.ResourcesTest.TabledSite,
            validate_config_inclusion?: false
        end
        """)
      end)

    assert warnings == ""

    page = Billboard.ResourcesTest.TabledPage
    version = Billboard.ResourcesTest.TabledVersion
    section = Billboard.ResourcesTest.TabledSection
    resources = [page, version, section]

    assert AshPostgres.DataLayer.Info.table(page) == "site_pages"
    assert AshPostgres.DataLayer.Info.table(version) == "page_versions"
    assert AshPostgres.DataLayer.Info.table(section) == "page_sections"

    assert indexes(page, resources) ==
             ~w(site_pages_one_library_index site_pages_unique_pattern_index)

    assert indexes(version, resources) ==
             ~w(page_versions_one_draft_per_page_index page_versions_one_live_per_page_index)

    assert indexes(section, resources) ==
             ~w(page_sections_parent_id_index page_sections_unique_anchor_index
                page_sections_unique_key_index)
  end

  # The names AshPostgres gives the resource's indexes as it writes its
  # migration: each identity's, and each custom index's.
  defp indexes(resource, resources) do
    [snapshot] = AshPostgres.MigrationGenerator.get_snapshots(resource, resources)
    table = AshPostgres.DataLayer.Info.table(resource)

    Enum.sort(
      Enum.map(snapshot.identities, & &1.index_name) ++
        Enum.map(snapshot.custom_indexes, &to_string(AshPostgres.CustomIndex.name(table, &1)))
    )
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
