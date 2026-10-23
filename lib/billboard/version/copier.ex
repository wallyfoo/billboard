defmodule Billboard.Version.Copier do
  @moduledoc """
  Copies sections into a version through `Section.copy`, keeping each
  one's key, anchor, content, surface, and position. Each top-level
  section is copied before its children, which then point at the copy.

  The sections come from the live version, or from a starter, so every one
  must have its `children` loaded: a section whose children weren't loaded
  would lose them silently.
  """

  @doc "Copies `sections`, with their children, into version `version_id`."
  @spec copy([struct()], Ecto.UUID.t(), Keyword.t()) :: :ok | {:error, term()}
  def copy(sections, version_id, opts) do
    each(sections, fn section ->
      with {:ok, copy} <- copy_one(section, version_id, nil, opts) do
        each(children!(section), &copy_one(&1, version_id, copy.id, opts))
      end
    end)
  end

  # The sections are the site's own section structs, from a live version
  # or a starter, so each is copied into its own resource.
  defp copy_one(section, version_id, parent_id, opts) do
    Ash.create(
      section.__struct__,
      %{
        version_id: version_id,
        parent_id: parent_id,
        key: section.key,
        anchor: section.anchor,
        content: section.content,
        surface: section.surface,
        position: section.position
      },
      [action: :copy] ++ opts
    )
  end

  defp each(sections, fun) do
    Enum.reduce_while(sections, :ok, fn section, :ok ->
      case fun.(section) do
        {:ok, _copy} -> {:cont, :ok}
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp children!(%{children: children}) when is_list(children), do: children

  defp children!(%{key: key}) do
    raise ArgumentError, "load the children of section #{inspect(key)} before copying it"
  end
end
