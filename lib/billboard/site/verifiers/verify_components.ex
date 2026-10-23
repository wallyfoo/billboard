defmodule Billboard.Site.Verifiers.VerifyComponents do
  @moduledoc """
  Checks the site's `components:`. Each must be a billboard component,
  since the content union and the palette are built from them, and no
  two may share a key, since a section's key is how billboard finds its
  component.

  Like every Spark verifier, it runs once the module has compiled, and
  its errors are printed as compile warnings rather than raised, so
  `mix compile --warnings-as-errors` fails on them.
  """
  use Spark.Dsl.Verifier

  alias Billboard.Component.Info
  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    site = Verifier.get_persisted(dsl_state, :module)
    components = Verifier.get_persisted(dsl_state, :billboard_answers)[:components]

    case Enum.reject(components, &component?/1) do
      [] -> verify_keys(site, components)
      others -> {:error, Enum.map(others, &error(site, not_a_component(site, &1)))}
    end
  end

  defp verify_keys(site, components) do
    components
    |> Enum.group_by(&Info.component_key!/1)
    |> Enum.filter(fn {_key, modules} -> length(modules) > 1 end)
    |> Enum.sort_by(fn {key, _modules} ->
      Enum.find_index(components, &(Info.component_key!(&1) == key))
    end)
    |> case do
      [] ->
        :ok

      twice ->
        {:error,
         Enum.map(twice, fn {key, modules} -> error(site, shared_key(site, key, modules)) end)}
    end
  end

  defp component?(module) do
    Code.ensure_compiled(module)
    Info.component?(module)
  end

  defp not_a_component(site, module) do
    "#{inspect(site)} lists #{inspect(module)} in `components:`, which isn't a billboard " <>
      "component. Add `use Billboard.Component` to it, or take it out of `components:`."
  end

  defp shared_key(site, key, [first, second]) do
    "#{inspect(site)} lists two components with the key #{inspect(key)}: " <>
      "#{inspect(first)} and #{inspect(second)}. Give one another key, or take one out."
  end

  defp shared_key(site, key, modules) do
    {last, others} = modules |> Enum.map(&inspect/1) |> List.pop_at(-1)

    "#{inspect(site)} lists #{length(modules)} components with the key #{inspect(key)}: " <>
      "#{Enum.join(others, ", ")}, and #{last}. Give all but one another key, or take them out."
  end

  defp error(site, message),
    do: Spark.Error.DslError.exception(module: site, path: [:components], message: message)
end
