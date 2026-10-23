defmodule Billboard.Section.Validations.Removable do
  @moduledoc """
  Keeps the sections a page can't do without: every page keeps its hero,
  and a fixed page (`Billboard.Directory`) keeps its top-level sections. A
  section inside Two columns can always go.
  """
  use Ash.Resource.Validation

  alias Billboard.Directory

  @impl true
  def validate(changeset, _opts, _context) do
    section = changeset.data

    cond do
      section.content.type == :hero ->
        {:error, message: "every page keeps its hero"}

      is_nil(section.parent_id) and fixed?(changeset.resource, section.version_id) ->
        {:error, message: "this page's sections are fixed"}

      true ->
        :ok
    end
  end

  defp fixed?(section, version_id) do
    version = Billboard.Resource.related(section, :version)
    %{page: page} = Ash.get!(version, version_id, authorize?: false, load: [:page])
    Directory.fixed?(page.pattern)
  end
end
