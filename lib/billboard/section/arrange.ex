defmodule Billboard.Section.Arrange do
  @moduledoc """
  Runs `Section.arrange`: puts a version's top-level sections in the given
  order, then moves each section whose place changed.

  The order must name every top-level section exactly once, and the hero,
  when there is one, stays first. A fixed page's sections can't move at
  all. Each move is a `:place`, which only a draft allows, so the live
  version can't be rearranged.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Billboard.Directory

  @impl true
  def run(input, _opts, context) do
    opts = Ash.Context.to_opts(context)
    %{version_id: version_id, order: order} = input.arguments
    version_resource = Billboard.Resource.related(input.resource, :version)

    with {:ok, version} <- Ash.get(version_resource, version_id, [load: [:page]] ++ opts),
         {:ok, sections} <- top_level(input.resource, version_id, opts),
         :ok <- not_fixed(version, sections, order),
         :ok <- complete(sections, order),
         :ok <- hero_first(sections, order) do
      move(sections, order, opts)
    end
  end

  defp top_level(resource, version_id, opts) do
    resource
    |> Ash.Query.filter(version_id == ^version_id and is_nil(parent_id))
    |> Ash.Query.sort(position: :asc)
    |> Ash.read(opts)
  end

  defp not_fixed(version, sections, order) do
    if Directory.fixed?(version.page.pattern) and Enum.map(sections, & &1.id) != order,
      do: invalid("this page's sections are fixed"),
      else: :ok
  end

  defp complete(sections, order) do
    if length(order) == length(Enum.uniq(order)) and
         MapSet.new(order) == MapSet.new(sections, & &1.id),
       do: :ok,
       else: invalid("the new order must list every section exactly once")
  end

  defp hero_first(sections, [first | _order]) do
    case Enum.find(sections, &(&1.content.type == :hero)) do
      %{id: ^first} -> :ok
      nil -> :ok
      _hero -> invalid("the hero stays first")
    end
  end

  defp hero_first(_sections, []), do: :ok

  defp move(sections, order, opts) do
    by_id = Map.new(sections, &{&1.id, &1})

    order
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {id, position}, :ok ->
      case Map.fetch!(by_id, id) do
        %{position: ^position} ->
          {:cont, :ok}

        section ->
          case Ash.update(section, %{position: position}, [action: :place] ++ opts) do
            {:ok, _section} -> {:cont, :ok}
            error -> {:halt, error}
          end
      end
    end)
  end

  defp invalid(message) do
    {:error, Ash.Error.Changes.InvalidArgument.exception(field: :order, message: message)}
  end
end
