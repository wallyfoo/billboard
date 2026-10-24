defmodule Billboard.ColocatedHooksTest do
  @moduledoc """
  The editor's colocated hooks are written where a site's bundler finds
  them, `phoenix-colocated/billboard` under the build path, which
  needs billboard to run LiveView's compiler itself (`mix.exs`).
  """
  use ExUnit.Case, async: true

  test "the editor's hooks are in billboard's colocated index" do
    index = Path.join([Mix.Project.build_path(), "phoenix-colocated", "billboard", "index.js"])

    assert File.exists?(index)
    js = File.read!(index)

    for hook <- ~w(Billboard.EditorLive.EditorBar Billboard.EditorLive.LocalTime
                   Billboard.Sections.EditorFields.CharacterCount) do
      assert js =~ hook
    end
  end
end
