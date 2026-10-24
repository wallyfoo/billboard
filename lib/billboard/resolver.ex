defmodule Billboard.Resolver do
  @moduledoc """
  Reads the data behind a page's sections, by section key, through the
  site's `Billboard.Data` (its `data:` answer), for the sections that
  draw rows from outside the builder, such as reviews and news.

  The page's STRUCTURE comes from `Billboard.Cache` (`Billboard.Pages.page_for/1`),
  or from a draft in the editor. The DATA is read here, per page view,
  because it changes outside the builder. It stays bounded: what the
  site's module reads with `Billboard.Data.once/3` is read at most once
  per page however many sections use it, and a component the page
  doesn't hold costs nothing.

  The result maps each data section's `key` to its data. Sections inside
  a Two columns section are resolved like top-level ones. A site with no
  data module reads nothing.
  """

  @doc """
  The data for each of `version`'s data sections, by section key, given
  the page's `context` (the map `Billboard.Context` describes). Each Two
  columns section needs its `children` loaded; this raises
  `ArgumentError` otherwise. It raises too when the data module's
  `fetch/3` returns neither `{:ok, value, loaded}` nor `:none`.
  """
  @spec resolve(map(), map()) :: %{String.t() => term()}
  def resolve(%{sections: sections}, context \\ %{}) do
    sections = Enum.flat_map(sections, &with_children/1)

    case Billboard.Site.data() do
      nil -> %{}
      data -> fetch_all(data, sections, context)
    end
  end

  defp fetch_all(data, sections, context) do
    {result, _loaded} =
      Enum.reduce(sections, {%{}, %{}}, fn %{key: key, content: content}, {result, loaded} ->
        case data.fetch(content.value, context, loaded) do
          {:ok, value, loaded} when is_map(loaded) ->
            {Map.put(result, key, value), loaded}

          :none ->
            {result, loaded}

          other ->
            raise "#{inspect(data)}.fetch/3 returned #{inspect(other)} for section #{inspect(key)}. " <>
                    "Return `{:ok, value, loaded}` (`Billboard.Data.once/3` gives one) or `:none`."
        end
      end)

    result
  end

  defp with_children(%{content: %Ash.Union{type: :columns}, children: children} = section)
       when is_list(children),
       do: [section | children]

  defp with_children(%{content: %Ash.Union{type: :columns}, key: key}) do
    raise ArgumentError,
          "load the children of Two columns section #{inspect(key)} before resolving its data"
  end

  defp with_children(section), do: [section]
end
