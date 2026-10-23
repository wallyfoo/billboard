defmodule Billboard.Errors.Refused do
  @moduledoc """
  Carries what a `Pages.change_draft/3` function turned its change down
  with (`reason`) out of the transaction it rolled back. Ash makes any
  error leaving a transaction an Ash error, so a plain reason, such as
  `:gone` or a form with errors on it, travels inside this one.
  """
  use Splode.Error, fields: [:reason], class: :invalid

  def message(%{reason: reason}), do: "the change was turned down: #{inspect(reason)}"
end
