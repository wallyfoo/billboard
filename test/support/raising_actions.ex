defmodule Billboard.Test.RaisingActions do
  @moduledoc "Action kinds whose list can't be read, for the cache's warning."
  @behaviour Billboard.Actions
  use Phoenix.Component

  @impl true
  def kinds, do: raise("the kinds are elsewhere")

  @impl true
  def action(assigns), do: ~H""
end
