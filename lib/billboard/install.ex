if Code.ensure_loaded?(Igniter) do
  defmodule Billboard.Install do
    @moduledoc false
    # The edits `mix billboard.install` and `mix billboard.gen.component`
    # make. Each looks for what it would write first and leaves what's
    # there alone, so a second run changes nothing. It's compiled only
    # with Igniter, as the tasks are, so a site without Igniter still
    # compiles billboard.

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Code.List, as: IList
    alias Sourceror.Zipper

    @doc "The site's names: its app, its modules, and the modules billboard writes."
    def names(igniter) do
      app = Igniter.Project.Application.app_name(igniter)
      prefix = Igniter.Project.Module.module_name_prefix(igniter)
      web = Igniter.Libs.Phoenix.web_module(igniter)

      %{
        app: app,
        name: app |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize(),
        prefix: inspect(prefix),
        web: inspect(web),
        site: Module.concat(prefix, Billboard),
        pages: Module.concat(prefix, Pages),
        repo: Module.concat(prefix, Repo),
        layouts: Module.concat(web, Layouts),
        endpoint: Module.concat(web, Endpoint),
        page_live: Module.concat(web, BillboardPageLive)
      }
    end

    @doc "`priv/templates/DIR/NAME`, rendered with `assigns`."
    def template(dir, name, assigns) do
      :billboard
      |> :code.priv_dir()
      |> Path.join("templates/#{dir}/#{name}")
      |> EEx.eval_file(assigns: Map.to_list(assigns))
    end

    @doc "Writes `module` from `contents`, unless the site has it already, wherever it lives."
    def create_module(igniter, module, contents, kind \\ :source_folder) do
      case Igniter.Project.Module.module_exists(igniter, module) do
        {true, igniter} ->
          igniter

        {false, igniter} ->
          path = Igniter.Project.Module.proper_location(igniter, module, kind)
          Igniter.create_new_file(igniter, path, contents)
      end
    end

    @doc "Whether `repo` does `use AshPostgres.Repo`."
    def ash_postgres_repo?(igniter, repo) do
      case Igniter.Project.Module.find_module(igniter, repo) do
        {:ok, {igniter, _source, zipper}} ->
          # `find_module/2` leaves the zipper on the `defmodule`; the
          # `use` is in its body.
          with {:ok, body} <- Common.move_to_do_block(zipper),
               {:ok, _use} <- Igniter.Code.Module.move_to_use(body, AshPostgres.Repo) do
            {igniter, true}
          else
            _ -> {igniter, false}
          end

        {:error, igniter} ->
          {igniter, false}
      end
    end

    @doc """
    Starts `Billboard.Cache` straight after the site's PubSub, which it
    broadcasts on, unless `start/2` names it already. (Igniter's
    `add_new_child/3` with `after:` puts a child one past the last match,
    after the endpoint.)
    """
    def add_cache(igniter) do
      case Igniter.Project.Application.app_module(igniter) do
        nil ->
          Igniter.add_warning(
            igniter,
            "Start `Billboard.Cache` in your application, after the repo and PubSub."
          )

        app ->
          app = with {module, _opts} <- app, do: module

          Igniter.Project.Module.find_and_update_module!(igniter, app, &add_cache(&1, app))
      end
    end

    defp add_cache(zipper, app) do
      case Function.move_to_def(zipper, :start, 2) do
        {:ok, start} ->
          cond do
            match?({:ok, _}, Common.move_to(start, &Common.nodes_equal?(&1, Billboard.Cache))) ->
              {:ok, zipper}

            pubsub = find_pubsub(start) ->
              {:ok, Zipper.insert_right(pubsub, Sourceror.parse_string!("Billboard.Cache"))}

            true ->
              {:warning,
               "Couldn't find `{Phoenix.PubSub, …}` in #{inspect(app)}'s children. Start " <>
                 "`Billboard.Cache` there yourself, after the repo and PubSub."}
          end

        :error ->
          {:warning, "Start `Billboard.Cache` in #{inspect(app)}, after the repo and PubSub."}
      end
    end

    defp find_pubsub(start) do
      with {:ok, assignment} <-
             Common.move_to(start, &match?({:=, _, [{:children, _, _}, _]}, &1.node)),
           list when not is_nil(list) <- assignment |> Zipper.down() |> Zipper.right(),
           {:ok, pubsub} <- IList.move_to_list_item(list, &pubsub?/1) do
        pubsub
      else
        _ -> nil
      end
    end

    defp pubsub?(item) do
      with true <- Igniter.Code.Tuple.tuple?(item),
           {:ok, first} <- Igniter.Code.Tuple.tuple_elem(item, 0) do
        Common.nodes_equal?(first, Phoenix.PubSub)
      else
        _ -> false
      end
    end

    @doc "Inserts each of `lines` that `path` lacks, after its first line starting with `after_prefix`."
    def add_lines(igniter, path, after_prefix, lines) do
      if Igniter.exists?(igniter, path) do
        Igniter.update_file(igniter, path, fn source ->
          content = Rewrite.Source.get(source, :content)

          case Enum.reject(lines, &String.contains?(content, &1)) do
            [] ->
              source

            missing ->
              {before, rest} =
                content
                |> String.split("\n")
                |> Enum.split_while(&(not String.starts_with?(&1, after_prefix)))

              lines =
                case rest do
                  [anchor | tail] -> before ++ [anchor | missing] ++ tail
                  [] -> missing ++ before
                end

              Rewrite.Source.update(source, :content, Enum.join(lines, "\n"))
          end
        end)
      else
        Igniter.add_warning(
          igniter,
          "There's no #{path}. Add these lines to your own:\n\n" <> Enum.join(lines, "\n")
        )
      end
    end

    @doc "Adds `line` to the end of `path`, making it if need be, unless it's there."
    def add_line(igniter, path, line) do
      Igniter.create_or_update_file(igniter, path, line <> "\n", fn source ->
        content = Rewrite.Source.get(source, :content)

        if content |> String.split("\n") |> Enum.member?(line),
          do: source,
          else:
            Rewrite.Source.update(
              source,
              :content,
              String.trim_trailing(content) <> "\n" <> line <> "\n"
            )
      end)
    end
  end
end
