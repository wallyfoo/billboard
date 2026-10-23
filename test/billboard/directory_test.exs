defmodule Billboard.DirectoryTest do
  @moduledoc "The pages the builder knows, from the site's `pages` section."
  # It names the site in application env, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Directory

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
