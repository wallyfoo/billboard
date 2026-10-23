defmodule Billboard.Site.Verifiers.VerifyResources do
  @moduledoc """
  Checks the modules the site's answers name for billboard to use: its
  page, version, and section resources must each do the `use` that
  writes that resource, its content must do `use Billboard.Content`, and
  its starter must define `version/1`. It checks only what the site
  gives, so a site that names none of them passes.

  Like every Spark verifier, it runs once the module has compiled, and
  its errors are printed as compile warnings rather than raised, so
  `mix compile --warnings-as-errors` fails on them.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    site = Verifier.get_persisted(dsl_state, :module)
    answers = Verifier.get_persisted(dsl_state, :billboard_answers)
    resources = answers[:resources]

    errors =
      [
        resource(site, :page, resources[:page]),
        resource(site, :version, resources[:version]),
        resource(site, :section, resources[:section]),
        content(site, resources[:content]),
        starter(site, answers[:starter])
      ]
      |> Enum.reject(&is_nil/1)

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp resource(_site, _kind, nil), do: nil

  defp resource(site, kind, module) do
    Code.ensure_compiled(module)

    unless Billboard.Resource.Kind.of(module) == kind do
      error(
        site,
        [:resources, kind],
        "#{inspect(site)} names #{inspect(module)} as its #{kind} resource, but it doesn't " <>
          "`use Billboard.#{kind |> to_string() |> Macro.camelize()}`."
      )
    end
  end

  defp content(_site, nil), do: nil

  defp content(site, module) do
    unless exports?(module, :billboard_site, 0) do
      error(
        site,
        [:resources, :content],
        "#{inspect(site)} names #{inspect(module)} as its content, but it doesn't " <>
          "`use Billboard.Content`."
      )
    end
  end

  defp starter(_site, nil), do: nil

  defp starter(site, module) do
    unless exports?(module, :version, 1) do
      error(
        site,
        [:starter],
        "#{inspect(site)}'s `starter:` is #{inspect(module)}, which doesn't define version/1. " <>
          "Give it `@behaviour Billboard.Starter` and its callbacks."
      )
    end
  end

  defp exports?(module, name, arity) do
    Code.ensure_compiled(module)
    Code.ensure_loaded?(module) and function_exported?(module, name, arity)
  end

  defp error(site, path, message),
    do: Spark.Error.DslError.exception(module: site, path: path, message: message)
end
