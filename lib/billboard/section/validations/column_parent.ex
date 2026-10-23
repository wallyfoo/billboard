defmodule Billboard.Section.Validations.ColumnParent do
  @moduledoc """
  A section sits inside another only as one of a Two columns section's
  columns: the parent must be on the same version, be a Two columns
  section, and sit at the top level itself, so layouts go one level deep.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :parent_id) do
      nil ->
        :ok

      parent_id ->
        check(changeset.resource, parent_id, Ash.Changeset.get_attribute(changeset, :version_id))
    end
  end

  defp check(section, parent_id, version_id) do
    case Ash.get(section, parent_id, authorize?: false, not_found_error?: false) do
      {:ok, %{version_id: ^version_id} = parent} -> check_parent(parent)
      _elsewhere_or_missing -> error("a section can only sit inside a section on the same page")
    end
  end

  defp check_parent(%{content: %Ash.Union{type: :columns}, parent_id: nil}), do: :ok

  defp check_parent(%{content: %Ash.Union{type: :columns}}),
    do: error("two columns go only one level deep, so they can't hold a section of their own")

  defp check_parent(_parent), do: error("a section can sit only inside Two columns")

  defp error(message), do: {:error, field: :parent_id, message: message}
end
