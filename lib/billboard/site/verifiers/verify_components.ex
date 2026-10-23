defmodule Billboard.Site.Verifiers.VerifyComponents do
  @moduledoc """
  Checks the site's `components:`. Each must be a billboard component,
  since the content union and the palette are built from them, each is
  listed once, and no two may share a key, since a section's key is how
  billboard finds its component. Each key `kinds:` narrows, and each key
  `palette: [hints: …]` words, must be one of theirs, and each once; and
  each page kind `kinds:` keeps a component to must be one a page in
  `pages` has, or `:library`, unless the site writes no pages. It
  reports every problem at once.

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
    answers = Verifier.get_persisted(dsl_state, :billboard_answers)
    listed = answers[:components]
    {components, others} = listed |> Enum.uniq() |> Enum.split_with(&component?/1)
    keys = Enum.map(components, &Info.component_key!/1)
    hints = Keyword.get(answers[:palette], :hints, [])

    messages =
      Enum.map(others, &{:components, not_a_component(site, &1)}) ++
        Enum.map(twice(listed), &{:components, listed_twice(site, &1)}) ++
        Enum.map(shared_keys(components), fn {key, modules} ->
          {:components, shared_key(site, key, modules)}
        end) ++
        for(
          {key, _page_kinds} <- Enum.uniq_by(answers[:kinds], &elem(&1, 0)),
          key not in keys,
          do: {:kinds, stray(site, key)}
        ) ++
        Enum.map(twice(Keyword.keys(answers[:kinds])), &{:kinds, narrowed_twice(site, &1)}) ++
        page_kinds(site, answers[:kinds], Verifier.get_entities(dsl_state, [:pages])) ++
        for(
          {key, _hint} <- Enum.uniq_by(hints, &elem(&1, 0)),
          key not in keys,
          do: {:palette, stray_hint(site, key)}
        ) ++
        Enum.map(twice(Keyword.keys(hints)), &{:palette, hinted_twice(site, &1)})

    case messages do
      [] ->
        :ok

      messages ->
        {:error, Enum.map(messages, fn {path, message} -> error(site, path, message) end)}
    end
  end

  # Each page kind `kinds:` keeps a component to that no page has. The
  # library is always there; a site that writes no pages of its own is
  # left alone, as one still being put together.
  defp page_kinds(site, kinds, pages) do
    case for(%{pattern: pattern, kind: kind} <- pages, not is_nil(pattern), do: kind) do
      [] ->
        []

      written ->
        offered = Enum.uniq(written ++ [:library])

        for {key, page_kinds} <- Enum.uniq_by(kinds, &elem(&1, 0)),
            page_kind <- Enum.uniq(page_kinds),
            page_kind not in offered,
            do: {:kinds, no_such_page(site, key, page_kind, offered)}
    end
  end

  # Each module or key listed more than once, in the order first listed.
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

  defp stray(site, key) do
    "#{inspect(site)} narrows the kinds of #{inspect(key)}, but lists no component with that " <>
      "key. Add the component to `components:`, or take #{inspect(key)} out of `kinds:`."
  end

  defp narrowed_twice(site, key),
    do: "#{inspect(site)} narrows #{inspect(key)} twice in `kinds:`. Take one out."

  defp no_such_page(site, key, page_kind, offered) do
    "#{inspect(site)} keeps #{inspect(key)} to the page kind #{inspect(page_kind)} in " <>
      "`kinds:`, but no page in `pages` has that kind. Use one of #{one_of(offered)}, or add " <>
      "a page of that kind."
  end

  defp stray_hint(site, key) do
    "#{inspect(site)} gives #{inspect(key)} a hint in `palette: [hints: …]`, but lists no " <>
      "component with that key. Add the component to `components:`, or take " <>
      "#{inspect(key)} out of `hints:`."
  end

  defp hinted_twice(site, key),
    do: "#{inspect(site)} gives #{inspect(key)} two hints in `palette: [hints: …]`. Take one out."

  defp one_of([only]), do: inspect(only)
  defp one_of([first, second]), do: "#{inspect(first)} and #{inspect(second)}"

  defp one_of(kinds) do
    {last, others} = kinds |> Enum.map(&inspect/1) |> List.pop_at(-1)
    "#{Enum.join(others, ", ")}, and #{last}"
  end

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

  defp error(site, path, message),
    do: Spark.Error.DslError.exception(module: site, path: [path], message: message)
end
