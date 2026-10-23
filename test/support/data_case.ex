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
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Billboard.Test.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
