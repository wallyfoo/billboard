defmodule Billboard.Site.Verifiers.VerifyResources do
  @moduledoc """
  Checks the modules the site's answers name for billboard to use: its
  page, version, and section resources must each do the `use` that
  writes that resource, its content must do `use Billboard.Content`, its
  starter must define `version/1`, its actions must be a module that
  defines `kinds/0` and `action/1` (`Billboard.Actions`), its context
  must be a module that, if it gives choices, says which
  (`Billboard.Context`), its data must be a module that defines
  `fetch/3` (`Billboard.Data`), and its layout must be a module that
  defines `page/1` (`Billboard.Layout`). It checks only what the site
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
        starter(site, answers[:starter]),
        actions(site, answers[:actions]),
        context(site, answers[:context]),
        data(site, answers[:data]),
        layout(site, answers[:layout])
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

  defp actions(_site, nil), do: nil

  defp actions(site, module) do
    cond do
      not match?({:module, _}, Code.ensure_compiled(module)) ->
        error(
          site,
          [:actions],
          "#{inspect(site)}'s `actions:` is #{inspect(module)}, which isn't a module. " <>
            "Name its `Billboard.Actions` module."
        )

      not (exports?(module, :kinds, 0) and exports?(module, :action, 1)) ->
        error(
          site,
          [:actions],
          "#{inspect(site)}'s `actions:` is #{inspect(module)}, which doesn't define kinds/0 " <>
            "and action/1. Give it `@behaviour Billboard.Actions` and its callbacks."
        )

      true ->
        nil
    end
  end

  defp context(_site, nil), do: nil

  defp context(site, module) do
    cond do
      not match?({:module, _}, Code.ensure_compiled(module)) ->
        error(
          site,
          [:context],
          "#{inspect(site)}'s `context:` is #{inspect(module)}, which isn't a module. " <>
            "Name its `Billboard.Context` module."
        )

      exports?(module, :choices, 1) and not exports?(module, :choice_sets, 0) ->
        error(
          site,
          [:context],
          "#{inspect(site)}'s `context:` is #{inspect(module)}, which defines choices/1 but " <>
            "not choice_sets/0. Give it `choice_sets/0`, listing the sets its choices/1 gives " <>
            "(`Billboard.Context`)."
        )

      exports?(module, :choice_sets, 0) and not exports?(module, :choices, 1) ->
        error(
          site,
          [:context],
          "#{inspect(site)}'s `context:` is #{inspect(module)}, which defines choice_sets/0 " <>
            "but not choices/1. Give it a `choices/1` clause for each set choice_sets/0 lists " <>
            "(`Billboard.Context`)."
        )

      true ->
        nil
    end
  end

  defp data(_site, nil), do: nil

  defp data(site, module) do
    cond do
      not match?({:module, _}, Code.ensure_compiled(module)) ->
        error(
          site,
          [:data],
          "#{inspect(site)}'s `data:` is #{inspect(module)}, which isn't a module. " <>
            "Name its `Billboard.Data` module."
        )

      not exports?(module, :fetch, 3) ->
        error(
          site,
          [:data],
          "#{inspect(site)}'s `data:` is #{inspect(module)}, which doesn't define fetch/3. " <>
            "Give it `@behaviour Billboard.Data` and its callback."
        )

      true ->
        nil
    end
  end

  defp layout(_site, nil), do: nil

  defp layout(site, module) do
    cond do
      not match?({:module, _}, Code.ensure_compiled(module)) ->
        error(
          site,
          [:layout],
          "#{inspect(site)}'s `layout:` is #{inspect(module)}, which isn't a module. " <>
            "Name its `Billboard.Layout` module."
        )

      not exports?(module, :page, 1) ->
        error(
          site,
          [:layout],
          "#{inspect(site)}'s `layout:` is #{inspect(module)}, which doesn't define page/1. " <>
            "Give it `@behaviour Billboard.Layout` and its callbacks."
        )

      true ->
        nil
    end
  end

  defp exports?(module, name, arity) do
    Code.ensure_compiled(module)
    Code.ensure_loaded?(module) and function_exported?(module, name, arity)
  end

  defp error(site, path, message),
    do: Spark.Error.DslError.exception(module: site, path: path, message: message)
end
