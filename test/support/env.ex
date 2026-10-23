defmodule Billboard.Test.Env do
  @moduledoc """
  Changes application env for one test and puts back what was there when
  the test ends. Application env is global, so a test module that uses
  this must not be async.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc """
  Merges `answers` into `Billboard.Test.Site`'s answers until the test
  ends, for example `put_site!(components: [Billboard.Test.Banner])`.
  """
  @spec put_site!(keyword()) :: :ok
  def put_site!(answers) when is_list(answers) do
    current = Application.get_env(:billboard, Billboard.Test.Site, [])
    put_env_for_test(:billboard, Billboard.Test.Site, Keyword.merge(current, answers))
  end

  @doc """
  Puts `value` under `app`'s `key` until the test ends, then puts back the
  value it had, or deletes the key if it had none. Calling it again for the
  same key in one test is safe: ExUnit runs `on_exit/1` callbacks last
  first, so the earliest value is the one that's restored.
  """
  @spec put_env_for_test(atom(), atom(), term()) :: :ok
  def put_env_for_test(app, key, value) do
    previous = Application.fetch_env(app, key)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(app, key, value)
        :error -> Application.delete_env(app, key)
      end
    end)

    Application.put_env(app, key, value)
  end
end
