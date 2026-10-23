defmodule Billboard.Section.Validations.SurfaceOffered do
  @moduledoc """
  Keeps a section's surface to the ones the site offers its kind
  (`Billboard.Surfaces.offered/1`), or `nil`, which is the kind's default. A section
  that takes its surface from elsewhere (`Billboard.Surfaces.taken_from/2`), which a
  Shared section, the hero, and a column all do, may only be `nil`, since
  a surface of its own would never be drawn.

  It checks when the surface changes, and when the content's type does,
  since a new type can be a new kind. A section whose surface and type both
  stay put keeps its surface even if the site has stopped offering it, so
  editing its words never fails over a choice nobody made just now.
  """
  use Ash.Resource.Validation

  alias Billboard.Surfaces

  @impl true
  def validate(changeset, _opts, _context) do
    surface = Ash.Changeset.get_attribute(changeset, :surface)
    type = type(Ash.Changeset.get_attribute(changeset, :content))

    cond do
      is_nil(surface) or is_nil(type) ->
        :ok

      not Ash.Changeset.changing_attribute?(changeset, :surface) and
          type == type(changeset.data.content) ->
        :ok

      source = Surfaces.taken_from(type, Ash.Changeset.get_attribute(changeset, :parent_id)) ->
        {:error, field: :surface, message: taken_from(source)}

      surface in Surfaces.offered(Surfaces.kind(type)) ->
        :ok

      true ->
        {:error, field: :surface, message: "“#{surface}” isn't a surface this section can take"}
    end
  end

  defp taken_from(:library), do: "a shared section takes its surface from its library section"
  defp taken_from(:layout), do: "the hero takes its surface from the page's header"
  defp taken_from(:parent), do: "a column takes its surface from its Two columns section"

  # Content that isn't a component yet has no type, and its own validation
  # says what's wrong with it, so there's no kind to check against.
  defp type(%Ash.Union{type: type}), do: type
  defp type(_content), do: nil
end
