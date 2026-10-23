defmodule Billboard.Parts.Point.Validations.LinksOnSite do
  @moduledoc """
  Keeps a point's link a plain link to a page on this site: a point is not
  the place for the site's own kinds of action (`Billboard.Actions`).
  """
  use Ash.Resource.Validation

  alias Billboard.Parts.Action

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :link) do
      nil -> :ok
      %Action{kind: :link} -> :ok
      %Action{} -> {:error, field: :link, message: "a point links to a page on this site"}
    end
  end
end
