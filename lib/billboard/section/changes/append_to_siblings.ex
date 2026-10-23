defmodule Billboard.Section.Changes.AppendToSiblings do
  @moduledoc """
  Puts a section at the end of the list it joins: its version's top level,
  or its parent's columns.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      version_id = Ash.Changeset.get_attribute(changeset, :version_id)
      parent_id = Ash.Changeset.get_attribute(changeset, :parent_id)
      position = next_position(changeset.resource, version_id, parent_id, changeset.data.id)
      Ash.Changeset.force_change_attribute(changeset, :position, position)
    end)
  end

  defp next_position(section, version_id, parent_id, id) do
    section
    |> Ash.Query.filter(version_id == ^version_id)
    |> siblings(parent_id)
    |> except(id)
    |> Ash.max!(:position, authorize?: false)
    |> case do
      nil -> 0
      last -> last + 1
    end
  end

  defp siblings(query, nil), do: Ash.Query.filter(query, is_nil(parent_id))
  defp siblings(query, parent_id), do: Ash.Query.filter(query, parent_id == ^parent_id)

  defp except(query, nil), do: query
  defp except(query, id), do: Ash.Query.filter(query, id != ^id)
end
