defmodule Billboard.Version.Copier do
  @moduledoc """
  Copies sections into a version through `Section.copy`, keeping each
  one's key, anchor, content, surface, and position. Each top-level
  section is copied before its children, which then point at the copy.

  The sections come from the live version, or from a starter, so every one
  must have its `children` loaded: a section whose children weren't loaded
  would lose them silently.
  """

  @doc """
  Copies `sections`, with their children, into version `version_id`, as
  records of `resource`, the version's section resource. Raises for a
  section that isn't one of `resource`'s structs.
  """
  @spec copy([struct()], Ecto.UUID.t(), module(), Keyword.t()) :: :ok | {:error, term()}
  def copy(sections, version_id, resource, opts) do
    each(sections, fn section ->
      with {:ok, copy} <- copy_one(section, version_id, nil, resource, opts) do
        each(children!(section), &copy_one(&1, version_id, copy.id, resource, opts))
      end
    end)
  end

  defp copy_one(section, version_id, parent_id, resource, opts) do
    section!(section, resource)

    Ash.create(
      resource,
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

  # Live sections are always the resource's own. A starter's must be too,
  # and one that isn't is the site's mistake, so this names it.
  defp section!(%resource{}, resource), do: :ok

  defp section!(section, resource) do
    given =
      case section do
        %struct{} -> "a %#{inspect(struct)}{}"
        %{} -> "a plain map"
        other -> inspect(other)
      end

    key = if is_map(section), do: " #{inspect(Map.get(section, :key))}", else: ""

    raise ArgumentError,
          "a starter gave section#{key} as #{given}, not a %#{inspect(resource)}{}. " <>
            "Build each of a starter's sections, and their children, as %#{inspect(resource)}{}"
  end

  defp children!(%{children: children}) when is_list(children), do: children

  defp children!(%{key: key}) do
    raise ArgumentError, "load the children of section #{inspect(key)} before copying it"
  end
end
