defmodule Billboard.SiteTest do
  # Changes application env, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Site

  describe "get!/0" do
    test "returns the configured module" do
      assert Site.get!() == Billboard.Test.Shop
    end

    test "raises, naming the fix, when no site is configured" do
      put_env_for_test(:billboard, :site, nil)

      assert_raise ArgumentError, ~r/config :billboard, site: MySite.Billboard/, fn ->
        Site.get!()
      end
    end
  end

  describe "the test site" do
    test "the shop is the configured site, with its components and pages" do
      assert Billboard.Site.get!() == Billboard.Test.Shop

      assert :columns in Enum.map(
               Billboard.Site.components(),
               &Billboard.Component.Info.component_key!/1
             )

      assert Enum.map(Billboard.Directory.pages(), & &1.pattern) ==
               ["/", "/about", "/items/:slug", "/terms", nil]
    end

    test "put_site!/1 makes the hand-written site the site for the test" do
      put_site!(components: [Billboard.Test.Note])
      assert Billboard.Site.get!() == Billboard.Test.Site
    end

    test "answers with its defaults" do
      assert Billboard.Test.Site.components() == []
      assert Enum.map(Billboard.Test.Site.surfaces(), & &1.name) == ["plain", "loud"]
      assert Billboard.Test.Site.offered() == [page: ["plain"], stand_out: ["loud"], card: []]
    end

    test "takes a test's own answers" do
      put_site!(rules: [SomeRule])
      assert Billboard.Test.Site.rules() == [SomeRule]
      assert Billboard.Test.Site.options() == []
    end
  end
end
