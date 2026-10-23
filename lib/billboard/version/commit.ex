defmodule Billboard.Version.Commit do
  @moduledoc """
  Runs `Version.commit`: checks the page's draft against `Billboard.Rules`,
  deletes the live version (its sections go with it), and makes the draft
  live. The action runs in a transaction, so if the draft can't be made
  live, the old live version comes back, and it holds the draft's row for
  update throughout, so the sections it checked are the ones it commits.

  A draft that breaks a rule stays a draft, and the error lists every rule
  it breaks. A library draft is also checked against every page that
  places its sections: none may give a section of its own the anchor of a
  shared section it places (`Rules.anchor_clashes/2`). Those pages are
  read as visitors see them, from `Billboard.Cache`, before the commit
  writes anything.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Billboard.{Catalogue, Directory, Pages, Rules}

  @impl true
  def run(input, _opts, context) do
    opts = Ash.Context.to_opts(context)
    pattern = input.arguments[:pattern]

    with {:ok, draft} <- draft(pattern, opts),
         :ok <- follows_rules(draft, pattern),
         :ok <- destroy_live(input.resource, draft.page_id, opts) do
      Ash.update(draft, %{}, [action: :make_live] ++ opts)
    end
  end

  # `draft_for/2` loads the draft's sections with their children, as the
  # rules need. The lock holds the draft's row until the commit ends: a
  # section write already under way finishes first, and one that starts
  # now waits, then finds the version live (`Section.Validations.DraftOnly`).
  # A second commit of the same draft waits too, then finds no draft.
  defp draft(pattern, opts) do
    case Pages.draft_for(pattern, [lock: :for_update] ++ opts) do
      {:ok, nil} -> invalid("there are no changes to commit")
      other -> other
    end
  end

  defp follows_rules(draft, pattern) do
    errors =
      Directory.fetch!(pattern)
      |> Rules.errors(draft.sections, Pages.shared_sections())
      |> Enum.map(& &1.message)

    case errors ++ placed_clashes(draft, pattern) do
      [] -> :ok
      messages -> invalid(Enum.join(messages, "; "))
    end
  end

  # A library commit changes the shared sections every page that places
  # them draws, so each page's current version (live, else its starter) is
  # checked against the draft's sections. A page's own commit checks its
  # page against the live library in `Rules`.
  defp placed_clashes(draft, nil) do
    shared = Map.new(draft.sections, &{&1.key, &1})

    for %{pattern: pattern} = page <- Directory.pages(),
        pattern != nil,
        {section, id} <- Rules.anchor_clashes(Pages.page_for(pattern).sections, shared) do
      "#{page.label} places a shared section with the anchor “#{id}”, " <>
        "which its #{Catalogue.label(section.content.type)} section already uses"
    end
  end

  defp placed_clashes(_draft, _pattern), do: []

  defp destroy_live(version, page_id, opts) do
    version
    |> Ash.Query.filter(status == :live and page_id == ^page_id)
    |> Ash.read_one(opts)
    |> case do
      {:ok, nil} -> :ok
      {:ok, live} -> Ash.destroy(live, opts)
      error -> error
    end
  end

  defp invalid(message) do
    {:error, Ash.Error.Changes.InvalidArgument.exception(field: :pattern, message: message)}
  end
end
