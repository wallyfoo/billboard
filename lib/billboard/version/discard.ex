defmodule Billboard.Version.Discard do
  @moduledoc """
  Runs `discard`: deletes the page's draft, if it has one. It holds the
  draft's row for update, as a commit does, so a section write under
  way finishes first.
  """
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(input, _opts, context) do
    opts = Ash.Context.to_opts(context)

    case Billboard.Pages.draft_for(input.arguments.pattern, [lock: :for_update] ++ opts) do
      {:ok, nil} -> :ok
      {:ok, draft} -> Ash.destroy(draft, opts)
      error -> error
    end
  end
end
