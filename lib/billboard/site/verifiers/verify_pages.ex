defmodule Billboard.Site.Verifiers.VerifyPages do
  @moduledoc """
  Checks the site's `pages` section, the library added: each pattern is
  written once and starts with `/`, the site has one library, no `page`
  takes the library's kind, and a fixed page fixes only components the
  site lists.

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
    pages = Verifier.get_entities(dsl_state, [:pages])

    keys =
      dsl_state
      |> Verifier.get_persisted(:billboard_answers)
      |> Keyword.fetch!(:components)
      |> Enum.filter(&component?/1)
      |> MapSet.new(&Info.component_key!/1)

    pages
    |> Enum.flat_map(&problems(&1, site, keys))
    |> Enum.concat(twice(pages, site))
    |> case do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp problems(%{kind: :library, pattern: nil}, _site, _keys), do: []

  defp problems(page, site, keys) do
    [
      not slash?(page.pattern) &&
        "#{inspect(site)}'s page #{inspect(page.pattern)} doesn't start with /. Write it " <>
          "as a route pattern, such as \"/#{page.pattern}\".",
      page.kind == :library &&
        "`:library` is the shared-sections library's kind. Give #{inspect(page.pattern)} " <>
          "a kind of the site's own, or write it as `library`."
      | for key <- page.fixed || [], key not in keys do
          "#{inspect(site)} fixes #{inspect(key)} on #{inspect(page.pattern)}, but lists no " <>
            "component with that key. Add it to `components:`, or take it out of `fixed:`."
        end
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&error(site, page, &1))
  end

  # Each pattern written more than once, once, and a second library.
  defp twice(pages, site) do
    pages
    |> Enum.group_by(& &1.pattern)
    |> Enum.filter(fn {_pattern, pages} -> length(pages) > 1 end)
    |> Enum.map(fn {pattern, [_first, second | _]} ->
      message =
        if is_nil(pattern),
          do: "#{inspect(site)} writes `library` twice. A site has one shared-sections library.",
          else: "#{inspect(site)} names the page #{inspect(pattern)} twice. Take one out."

      error(site, second, message)
    end)
  end

  defp slash?(pattern), do: String.starts_with?(pattern, "/")

  defp component?(module) do
    Code.ensure_compiled(module)
    Info.component?(module)
  end

  defp error(site, page, message) do
    Spark.Error.DslError.exception(
      module: site,
      path: [:pages, page.pattern],
      location: Spark.Dsl.Entity.anno(page),
      message: message
    )
  end
end
