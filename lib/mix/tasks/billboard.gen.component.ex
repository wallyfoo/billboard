if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Billboard.Gen.Component do
    @shortdoc "Writes a billboard component: its data module, renderer, and test"
    @moduledoc """
    #{@shortdoc}, and lists it in the site module's `components:`.

        mix billboard.gen.component MySite.Sections.Faq --list question

    writes `MySite.Sections.Faq`, a title and a list of questions;
    `MySite.Sections.Faq.Question`, the part each question is
    (`Billboard.Part`); `MySiteWeb.Sections.Faq`, which draws it; and
    `MySite.Sections.FaqTest`, which checks it works with
    `Billboard.ComponentCase`. Without `--list`, it's a title and some
    words. The skeleton works as written: change it from there.

    A module the site has already is never written over: a component is
    left as it is, and still listed, so running it again changes nothing,
    and a module that isn't a component stops the run. So does a part or
    renderer module the site has that isn't a part or a renderer, and a
    key that a component `components:` lists already has, such as
    `:band` for `MySite.Sections.Band` beside `Billboard.Components.Band`.

    ## Options

      * `--list NAME` - a list of NAMEs, each the part the generator
        writes, with a title and a body.
      * `--key KEY` - the key the content is stored under, which never
        changes once there's content. Defaults to the module's last
        name, underscored: `:faq`.
      * `--renderer MODULE` - the renderer. Defaults to the module with
        the site's web module for its first name: `MySiteWeb.Sections.Faq`.
      * `--site MODULE` - the site module to list it in. Defaults to
        `MySite.Billboard`, or the module `config :billboard, :site` names.
    """
    use Igniter.Mix.Task

    alias Billboard.Install

    @name ~r/^[a-z][a-z0-9_]*$/

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :billboard,
        example: "mix billboard.gen.component MySite.Sections.Faq --list question",
        positional: [:module],
        schema: [list: :string, key: :string, renderer: :string, site: :string]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      {igniter, names} = Install.names(igniter)
      component = Igniter.Project.Module.parse(igniter.args.positional.module)

      with {:ok, assigns} <- assigns(names, component, igniter.args.options),
           {:ok, igniter, exists?} <- existing(igniter, component),
           {:ok, igniter} <- free_key(igniter, assigns, exists?),
           {:ok, igniter} <- own_modules(igniter, assigns, exists?) do
        igniter
        |> write(assigns, exists?)
        |> Install.list_component(assigns.site, component)
      else
        {:issue, message} -> Igniter.add_issue(igniter, message)
        {:error, igniter} -> igniter
      end
    end

    # A new component's key must be one no listed component has: the
    # site's content union can't hold two components under one key.
    defp free_key(igniter, _assigns, true), do: {:ok, igniter}

    defp free_key(igniter, assigns, false) do
      {igniter, keys} = Install.listed_keys(igniter, assigns.site)

      case Enum.find(keys, fn {key, _module} -> Atom.to_string(key) == assigns.key end) do
        nil ->
          {:ok, igniter}

        {key, module} ->
          {:error,
           Igniter.add_issue(
             igniter,
             "`#{inspect(key)}` is #{inspect(module)}'s key, which #{inspect(assigns.site)} " <>
               "lists, so nothing was written. Name another with `--key`, or take " <>
               "#{inspect(module)} out of `components:` to replace it."
           )}
      end
    end

    # A new component's part and renderer, when the site has a module
    # under either name already, must be a part and a renderer: the
    # component would name them, and nothing of them is written over.
    defp own_modules(igniter, _assigns, true), do: {:ok, igniter}

    defp own_modules(igniter, assigns, false) do
      [
        {assigns.part, Billboard.Part, "part", "--list"},
        {assigns.renderer, Billboard.Renderer, "renderer", "--renderer"}
      ]
      |> Enum.reject(fn {module, _, _, _} -> is_nil(module) end)
      |> Enum.reduce_while({:ok, igniter}, fn {module, using, what, option}, {:ok, igniter} ->
        module = Igniter.Project.Module.parse(module)

        case Igniter.Project.Module.find_module(igniter, module) do
          {:ok, {igniter, _source, zipper}} ->
            if uses?(zipper, using) do
              {:cont, {:ok, igniter}}
            else
              {:halt,
               {:error,
                Igniter.add_issue(
                  igniter,
                  "#{inspect(module)} is in the site already, and isn't a billboard #{what} " <>
                    "(it has no `use #{inspect(using)}`), so nothing was written. Name " <>
                    "another with `#{option}`."
                )}}
            end

          {:error, igniter} ->
            {:cont, {:ok, igniter}}
        end
      end)
    end

    # A component the site has is its own by now: none of its modules is
    # written over, and it's still listed.
    defp write(igniter, assigns, true) do
      Igniter.add_notice(
        igniter,
        "#{assigns.component} is in the site already, so nothing of it is written over: " <>
          "it, and any part, renderer, or test it has, are left as they are."
      )
    end

    defp write(igniter, assigns, false) do
      igniter
      |> create(assigns.component, "component.ex.eex", assigns)
      |> create(assigns.part, "part.ex.eex", assigns)
      |> create(assigns.renderer, "renderer.ex.eex", assigns)
      |> create(assigns.test, "test.exs.eex", assigns, :test)
    end

    defp create(igniter, module, template, assigns, kind \\ :source_folder)
    defp create(igniter, nil, _template, _assigns, _kind), do: igniter

    defp create(igniter, module, template, assigns, kind) do
      Install.create_module(
        igniter,
        Igniter.Project.Module.parse(module),
        Install.template("billboard.gen.component", template, assigns),
        kind
      )
    end

    # Whether the site has the component already. Any other module under
    # its name stops the run, since listing that would break the site.
    defp existing(igniter, component) do
      case Igniter.Project.Module.find_module(igniter, component) do
        {:ok, {igniter, _source, zipper}} ->
          if component?(zipper) do
            {:ok, igniter, true}
          else
            {:error,
             Igniter.add_issue(
               igniter,
               "#{inspect(component)} is in the site already, and isn't a billboard component " <>
                 "(it has no `use Billboard.Component`), so nothing was written. Give the " <>
                 "component another name."
             )}
          end

        {:error, igniter} ->
          {:ok, igniter, false}
      end
    end

    defp component?(zipper), do: uses?(zipper, Billboard.Component)

    defp uses?(zipper, module) do
      with {:ok, body} <- Igniter.Code.Common.move_to_do_block(zipper),
           {:ok, _use} <- Igniter.Code.Module.move_to_use(body, module) do
        true
      else
        _ -> false
      end
    end

    defp assigns(names, component, opts) do
      key = opts[:key] || component |> Module.split() |> List.last() |> Macro.underscore()

      with :ok <- check_key(key),
           {:ok, list} <- list(opts[:list]),
           {:ok, renderer} <- renderer(names, component, opts[:renderer]) do
        last = component |> Module.split() |> List.last()
        label = last |> Macro.underscore() |> String.replace("_", " ") |> String.capitalize()

        {:ok,
         Map.merge(list, %{
           component: inspect(component),
           key: key,
           label: label,
           article: if(String.match?(label, ~r/^[AEIOU]/), do: "an", else: "a"),
           renderer: renderer,
           test: inspect(component) <> "Test",
           site: if(opts[:site], do: Igniter.Project.Module.parse(opts[:site]), else: names.site),
           endpoint: inspect(names.endpoint),
           repo: names.repo && inspect(names.repo),
           part: list.item && inspect(component) <> "." <> Macro.camelize(list.item)
         })}
      end
    end

    defp check_key(key) do
      if Regex.match?(@name, key),
        do: :ok,
        else:
          {:issue,
           "`--key` names the key content is stored under, as `--key faq`: lowercase " <>
             "letters, digits, and underscores, starting with a letter. #{inspect(key)} isn't one."}
    end

    defp list(nil), do: {:ok, %{item: nil, list: nil}}

    defp list(item) do
      if Regex.match?(@name, item),
        do: {:ok, %{item: item, list: Igniter.Inflex.pluralize(item)}},
        else:
          {:issue,
           "`--list` names one item of the list, as `--list question`: lowercase letters, " <>
             "digits, and underscores, starting with a letter. #{inspect(item)} isn't one."}
    end

    defp renderer(_names, _component, renderer) when is_binary(renderer),
      do: {:ok, renderer |> Igniter.Project.Module.parse() |> inspect()}

    defp renderer(names, component, nil) do
      prefix = String.split(names.prefix, ".")
      parts = Module.split(component)

      if List.starts_with?(parts, prefix) and parts != prefix do
        {:ok, Enum.join([names.web | Enum.drop(parts, length(prefix))], ".")}
      else
        {:issue,
         "#{inspect(component)} isn't under #{names.prefix}, so its renderer can't be named " <>
           "after it. Name one with `--renderer`, as " <>
           "`--renderer #{names.web}.Sections.#{List.last(parts)}`."}
      end
    end
  end
else
  defmodule Mix.Tasks.Billboard.Gen.Component do
    @shortdoc "Writes a billboard component: its data module, renderer, and test"
    @moduledoc "#{@shortdoc}. It needs Igniter: see the error it raises."
    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.raise(
        "mix billboard.gen.component needs Igniter. Add `{:igniter, \"~> 0.8\", only: [:dev, :test]}` " <>
          "to your deps, run mix deps.get, and run mix billboard.gen.component again"
      )
    end
  end
end
