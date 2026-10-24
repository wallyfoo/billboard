defmodule Billboard.Test.LiveCase do
  @moduledoc """
  For tests of LiveViews on the shop: the SQL sandbox, as
  `Billboard.Test.DataCase` sets it up, `Phoenix.LiveViewTest`, and
  `signed_in/1`.

  A LiveView runs in its own process, which reaches the sandbox only
  when the owner is shared. Billboard has no `Phoenix.Ecto.SQL.Sandbox`
  to let an async test hand its connection on, so LiveView tests run
  `async: false`, which shares it.
  """
  use ExUnit.CaseTemplate

  using opts do
    if opts[:async] do
      raise ArgumentError,
            "#{inspect(__CALLER__.module)} uses Billboard.Test.LiveCase with `async: true`, " <>
              "but LiveView tests run async: false, so the LiveView shares the test's " <>
              "connection. Use `use Billboard.Test.LiveCase, async: false`."
    end

    quote do
      @endpoint Billboard.Test.Endpoint

      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Billboard.Test.{DataCase, Env, Fixtures, LiveCase}
    end
  end

  setup tags do
    Billboard.Test.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc "`conn`, signed in as the shop's admin."
  def signed_in(conn), do: Plug.Test.init_test_session(conn, %{"signed_in" => true})
end
