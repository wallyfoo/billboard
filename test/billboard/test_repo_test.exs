defmodule Billboard.TestRepoTest do
  @moduledoc "The test site's database is up, and each test writes inside the SQL sandbox."
  use Billboard.Test.DataCase, async: true

  alias Billboard.Test.Repo

  # The sandbox's own transaction is hidden: `in_transaction?/0` is false
  # outside one the test opens, which `Billboard.Cache` relies on.
  test "answers a query, and runs a transaction of its own" do
    assert %{rows: [[1]]} = Repo.query!("SELECT 1")
    refute Repo.in_transaction?()
    assert {:ok, true} = Repo.transaction(fn -> Repo.in_transaction?() end)
  end
end
