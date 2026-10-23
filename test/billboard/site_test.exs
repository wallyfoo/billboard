defmodule Billboard.SiteTest do
  # Changes application env, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Site

  describe "get!/0" do
    test "returns the configured module" do
      assert Site.get!() == Billboard.Test.Site
    end

    test "raises, naming the fix, when no site is configured" do
      put_env_for_test(:billboard, :site, nil)

      assert_raise ArgumentError, ~r/config :billboard, site: MySite.Billboard/, fn ->
        Site.get!()
      end
    end
  end

  describe "the test site" do
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
