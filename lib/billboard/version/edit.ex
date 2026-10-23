defmodule Billboard.Version.Edit do
  @moduledoc """
  Runs `Version.edit`: returns the page's draft, first making one from its
  live version, or from its starter if it has never been committed. Keys
  are copied with the sections, so the editor can find a section in the new
  draft by the key it showed for the live one. The draft comes back with
  its sections and their children loaded.

  A page's first edit makes its record (`Billboard.Pages.ensure_page/2`).
  The page's unique pattern and the `one_draft_per_page` identity guard
  against two admins making their first edit in the same instant: the
  second insert fails, and `Billboard.Pages.change_draft/3` tries that
  admin's change again, finding the first one's draft.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Billboard.{Directory, Pages, Site}
  alias Billboard.Version.Copier

  @impl true
  def run(input, _opts, context) do
    opts = Ash.Context.to_opts(context)
    pattern = input.arguments[:pattern]
    version_resource = input.resource
    section_resource = Billboard.Resource.related(version_resource, :sections)

    with {:ok, _known} <- known(pattern),
         {:ok, page} <- Pages.ensure_page(pattern, opts),
         {:ok, nil} <- Site.domain!().get_draft(page.id, opts),
         {:ok, sections} <- source_sections(version_resource, page, pattern, opts),
         {:ok, draft} <- Ash.create(version_resource, %{page_id: page.id}, opts),
         :ok <- Copier.copy(sections, draft.id, section_resource, opts) do
      # Read back through `:draft`, so a new draft comes with its sections
      # and their children, as an existing one does.
      Site.domain!().get_draft(page.id, opts)
    else
      {:ok, %^version_resource{} = draft} -> {:ok, draft}
      error -> error
    end
  end

  defp known(pattern) do
    case Directory.fetch(pattern) do
      nil ->
        {:error,
         Ash.Error.Changes.InvalidArgument.exception(
           field: :pattern,
           message: "there is no such page"
         )}

      page ->
        {:ok, page}
    end
  end

  # The live version's sections, else the starter's.
  defp source_sections(version_resource, page, pattern, opts) do
    version_resource
    |> Ash.Query.for_read(:live, %{}, opts)
    |> Ash.Query.filter(page_id == ^page.id)
    |> Ash.read_one(opts)
    |> case do
      {:ok, %{sections: sections}} -> {:ok, sections}
      {:ok, nil} -> {:ok, Site.starter(pattern).sections}
      error -> error
    end
  end
end
