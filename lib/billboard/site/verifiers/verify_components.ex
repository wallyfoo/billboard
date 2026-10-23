defmodule Billboard.Site.Verifiers.VerifyComponents do
  @moduledoc """
  Checks the site's `components:`. Each must be a billboard component,
  since the content union and the palette are built from them, each is
  listed once, and no two may share a key, since a section's key is how
  billboard finds its component. It reports every problem at once.

  Like every Spark verifier, it runs once the module has compiled, and
  its errors are printed as compile warnings rather than raised, so
  `mix compile --warnings-as-errors` fails on them. The site module
  doesn't depend on its components, so a change to a component, such as
  its key, isn't checked here until the site module recompiles.
  """
  use Spark.Dsl.Verifier

  alias Billboard.Component.Info
  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    site = Verifier.get_persisted(dsl_state, :module)
    listed = Verifier.get_persisted(dsl_state, :billboard_answers)[:components]
    {components, others} = listed |> Enum.uniq() |> Enum.split_with(&component?/1)

    messages =
      Enum.map(others, &not_a_component(site, &1)) ++
        Enum.map(twice(listed), &listed_twice(site, &1)) ++
        Enum.map(shared_keys(components), fn {key, modules} -> shared_key(site, key, modules) end)

    case messages do
      [] -> :ok
      messages -> {:error, Enum.map(messages, &error(site, &1))}
    end
  end

  # Each module listed more than once, in the order first listed.
  defp twice(listed) do
    listed
    |> Enum.frequencies()
    |> Enum.filter(fn {_module, count} -> count > 1 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort_by(fn module -> Enum.find_index(listed, &(&1 == module)) end)
  end

  # Each key two or more components share, with them, in the order listed.
  defp shared_keys(components) do
    components
    |> Enum.group_by(&Info.component_key!/1)
    |> Enum.filter(fn {_key, modules} -> length(modules) > 1 end)
    |> Enum.sort_by(fn {_key, [first | _]} -> Enum.find_index(components, &(&1 == first)) end)
  end

  defp component?(module) do
    Code.ensure_compiled(module)
    Info.component?(module)
  end

  defp not_a_component(site, module) do
    "#{inspect(site)} lists #{inspect(module)} in `components:`, which isn't a billboard " <>
      "component. Add `use Billboard.Component` to it, or take it out of `components:`."
  end

  defp listed_twice(site, module),
    do: "#{inspect(site)} lists #{inspect(module)} twice in `components:`. Take one out."

  defp shared_key(site, key, [first, second]) do
    "#{inspect(site)} lists two components with the key #{inspect(key)}: " <>
      "#{inspect(first)} and #{inspect(second)}. Give one another key, or take one out."
  end

  defp shared_key(site, key, modules) do
    {last, others} = modules |> Enum.map(&inspect/1) |> List.pop_at(-1)

    "#{inspect(site)} lists #{length(modules)} components with the key #{inspect(key)}: " <>
      "#{Enum.join(others, ", ")}, and #{last}. Give all but one another key, or take " <>
      "all but one out."
  end

  defp error(site, message),
    do: Spark.Error.DslError.exception(module: site, path: [:components], message: message)
end
