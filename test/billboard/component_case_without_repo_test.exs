defmodule Billboard.ComponentCaseWithoutRepoTest do
  @moduledoc "A ComponentCase without `repo:` names it when a section reads the database."
  use Billboard.ComponentCase, endpoint: Billboard.Test.Endpoint, async: false

  import Billboard.Test.MisdrawnRenderer, only: [misdraw!: 1]

  alias Billboard.ComponentCase

  # The LiveView's own process logs its crash.
  @tag capture_log: true
  test "names `repo:` when the open section reads the database without a connection" do
    misdraw!([:reads_database])

    error =
      assert_raise ExUnit.AssertionError, fn ->
        ComponentCase.check_open(Billboard.Test.Misdrawn, page: "/")
      end

    assert error.message =~
             "Misdrawn's section reads the database when it's drawn open in the editor, " <>
               "but the test holds no connection for it"

    assert error.message =~ "repo: MySite.Repo`"
  end
end
