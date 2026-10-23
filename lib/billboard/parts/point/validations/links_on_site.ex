defmodule Billboard.Parts.Point.Validations.LinksOnSite do
  @moduledoc """
  Keeps a point's link a plain link to a page on this site: a point is not
  the place for the site's own kinds of action (`Billboard.Actions`).
  """
  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute
  alias Billboard.Parts.Action

  # The error is an exception, not a keyword list: a part in a list is
  # cast with the others through Ash's bulk create, which reports a
  # keyword list as an unknown error rather than an invalid field.
  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :link) do
      nil ->
        :ok

      %Action{kind: :link} ->
        :ok

      %Action{} ->
        {:error,
         InvalidAttribute.exception(field: :link, message: "a point links to a page on this site")}
    end
  end
end
