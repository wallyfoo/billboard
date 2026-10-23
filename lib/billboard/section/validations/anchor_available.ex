defmodule Billboard.Section.Validations.AnchorAvailable do
  @moduledoc """
  Keeps a section's anchor clear of the DOM ids the site gives other
  things: billboard's own, which are the hero's (`page-hero`, and `main`,
  the skip link's target), the Show all buttons' (`…-show-all`), the ids
  made from section keys (`section-…`, see `Billboard.Section.dom_id/1`),
  and the page editor's (`editor-bar`, `edit-…`, `open-…`, `words-…`,
  and the like), which share a page with the sections it draws; and the
  site's own, from its `reserved_ids:` (`Billboard.Site`), such as its
  header's and its sections' rows. A component may take an id the site
  says it owns. Two elements with one id would break in-page links, and
  the scripts and tests that find them.

  It also keeps an anchor to one section of a version. The `unique_anchor`
  identity holds that in the database, but a clash found there aborts the
  transaction around it and names no field, so this finds it first and
  says so on the anchor. The copier (`siblings: false`) copies anchors
  that are already unique.
  """
  use Ash.Resource.Validation

  require Ash.Query

  # What billboard draws itself: the hero (`page-hero`, and `main`, the
  # skip link's target), Show all buttons, the ids made from section
  # keys (`Billboard.Section.dom_id/1`), and the page editor's own.
  @taken ~w(main page-hero edit-canvas editor-bar page-issues page-picker draft-status
            commit-changes discard-changes mode-edit mode-view)
  @prefixes ~w(section- edit- open- words-)
  @suffixes ~w(-show-all)

  @impl true
  def init(opts), do: {:ok, Keyword.put_new(opts, :siblings, true)}

  @impl true
  def validate(changeset, opts, _context) do
    anchor = Ash.Changeset.get_attribute(changeset, :anchor)

    cond do
      not is_binary(anchor) ->
        :ok

      taken?(anchor, component(changeset)) ->
        {:error,
         field: :anchor,
         message: "the site already uses “#{anchor}” for something else; choose another"}

      opts[:siblings] and Ash.Changeset.changing_attribute?(changeset, :anchor) and
          sibling_has?(changeset, anchor) ->
        {:error,
         field: :anchor, message: "another section on this page is “#{anchor}”; choose another"}

      true ->
        :ok
    end
  end

  defp sibling_has?(changeset, anchor) do
    case Ash.Changeset.get_attribute(changeset, :version_id) do
      nil ->
        false

      version_id ->
        id = Ash.Changeset.get_attribute(changeset, :id)

        changeset.resource
        |> Ash.Query.filter(version_id == ^version_id and anchor == ^anchor)
        |> then(&if(id, do: Ash.Query.filter(&1, id != ^id), else: &1))
        |> Ash.exists?(authorize?: false)
    end
  end

  defp taken?(anchor, component) do
    site = Billboard.Site.reserved_ids()

    case Map.fetch(Keyword.get(site, :owned, %{}), anchor) do
      {:ok, owner} ->
        owner != component

      :error ->
        anchor in @taken or anchor in Keyword.get(site, :ids, []) or
          String.starts_with?(anchor, @prefixes ++ Keyword.get(site, :prefixes, [])) or
          String.ends_with?(anchor, @suffixes ++ Keyword.get(site, :suffixes, []))
    end
  end

  defp component(changeset) do
    case Ash.Changeset.get_attribute(changeset, :content) do
      %Ash.Union{type: type} -> type
      _content -> nil
    end
  end
end
