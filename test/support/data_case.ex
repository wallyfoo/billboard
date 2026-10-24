defmodule Billboard.Test.DataCase do
  @moduledoc """
  For tests that read and write the test site's tables. Each test runs in
  the SQL sandbox, so what it writes is gone when it ends. `async: true`
  is safe unless the test changes application env or the pages cache,
  which every test shares.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import Billboard.Test.DataCase
      import Billboard.Test.Env
      import Billboard.Test.Fixtures
    end
  end

  setup tags do
    setup_sandbox(tags)
    :ok
  end

  @doc """
  Starts the test's sandbox owner, and stops it when the test ends. An
  `async: false` test shares the owner's connection with every process,
  such as a LiveView's, so they read and write in the test's
  transaction.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Billboard.Test.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Puts back the pages cache as it was when the test started. The cache is
  shared by every test, so a test that refreshes it runs `async: false`
  and uses this.
  """
  def preserve_cache(_context) do
    snapshot = Billboard.Cache.snapshot()
    on_exit(fn -> Billboard.Cache.put(snapshot) end)
    :ok
  end

  @doc """
  Runs `fun` while the database can't read `table`, and returns its result.

  The table is renamed, then renamed back. The sandbox runs each query in
  a savepoint, so the failed reads don't abort the test's transaction,
  and that transaction's rollback undoes the renames anyway. The rename
  locks the table until the test ends, so only `async: false` tests may
  use this.
  """
  def without_table(table, fun) do
    Billboard.Test.Repo.query!(~s(ALTER TABLE "#{table}" RENAME TO "#{table}_away"))

    try do
      fun.()
    after
      Billboard.Test.Repo.query!(~s(ALTER TABLE "#{table}_away" RENAME TO "#{table}"))
    end
  end
end
