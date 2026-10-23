defmodule Billboard.Section.Validations.DraftOnly do
  @moduledoc """
  Keeps the live version as it was committed: a section can be added,
  copied in, changed, moved, or removed only on a draft. A live version
  only ever comes from committing a draft.

  Run it with `before_action?: true`, so it reads the version inside the
  write's transaction. The read takes a share lock on the version's row,
  so a section write waits for a commit already under way (which holds
  the draft's row for update), then sees the version is live and stops;
  and a commit waits for section writes already under way.
  """
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    version = Billboard.Resource.related(changeset.resource, :version)

    changeset
    |> Ash.Changeset.get_attribute(:version_id)
    |> status(version)
    |> case do
      :live -> {:error, message: "edit the page's draft, not its live layout"}
      _draft_or_missing -> :ok
    end
  end

  # A missing version is left to the foreign key, which says so better.
  defp status(nil, _version), do: nil

  defp status(version_id, version) do
    version
    |> Ash.Query.filter(id == ^version_id)
    |> Ash.Query.lock("FOR SHARE")
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{status: status}} -> status
      _missing -> nil
    end
  end
end
