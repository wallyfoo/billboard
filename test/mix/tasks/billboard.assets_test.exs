defmodule Mix.Tasks.Billboard.AssetsTest do
  @moduledoc "Links billboard's assets into the site, at one path, whatever kind of dependency it is."
  use ExUnit.Case, async: false

  @to "tmp/test-assets/vendor/billboard"

  setup do
    File.rm_rf!("tmp/test-assets")
    on_exit(fn -> File.rm_rf!("tmp/test-assets") end)
  end

  test "links billboard where the site's assets import it, and again when it moves" do
    Mix.Tasks.Billboard.Assets.run(["--to", @to])
    assert File.read_link!(@to) == File.cwd!()
    assert File.exists?(Path.join(@to, "assets/css/theme.css"))

    Mix.Tasks.Billboard.Assets.run(["--to", @to])
    assert File.read_link!(@to) == File.cwd!()
  end

  test "won't replace a directory of the site's own" do
    File.mkdir_p!(@to)

    assert_raise Mix.Error, ~r/isn't a link/, fn ->
      Mix.Tasks.Billboard.Assets.run(["--to", @to])
    end
  end
end
