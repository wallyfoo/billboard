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

    @doc "Adds billboard's page layout to the site's `Layouts`, unless it has a `page/1`."
    def add_layout(igniter, names) do
      code = template("billboard.install", "layout.ex.eex", names)

      igniter
      |> Igniter.Project.Module.find_and_update_module(names.layouts, fn zipper ->
        case Function.move_to_def(zipper, :page, 1) do
          {:ok, _} -> {:ok, zipper}
          :error -> {:ok, Common.add_code(zipper, code)}
        end
      end)
      |> case do
        {:ok, igniter} ->
          igniter

        {:error, igniter} ->
          Igniter.add_warning(
            igniter,
            "There's no #{inspect(names.layouts)}. Give your layouts module a `page/1` for " <>
              "billboard (`@behaviour Billboard.Layout`), and name it as `layout:` in " <>
              "`use Billboard.Site`."
          )
      end
    end

    @doc "Imports the editor's router macro, and mounts the editor in the signed-in live_session."
    def mount_editor(igniter, opts) do
      {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
      web = Igniter.Libs.Phoenix.web_module(igniter)
      # A name typed on the command line, once, so the atom is safe.
      session = String.to_atom(opts[:live_session])
      route = ~s|billboard_editor #{inspect(opts[:editor_path])}, back: {"Home", "/"}|

      if router do
        igniter
        |> Igniter.Project.Module.find_and_update_module!(
          router,
          &import_editor_router(&1, web, router)
        )
        |> Igniter.Project.Module.find_and_update_module!(
          router,
          &add_editor_route(&1, session, route, router)
        )
      else
        Igniter.add_warning(
          igniter,
          "There's no router. Add `import Billboard.Editor.Router` to yours, and mount " <>
            "the editor inside its signed-in live_session: #{route}"
        )
      end
    end

    defp import_editor_router(zipper, web, router) do
      if found?(zipper, &import?(&1, Billboard.Editor.Router)) do
        {:ok, zipper}
      else
        case Igniter.Code.Module.move_to_use(zipper, web) do
          {:ok, use} ->
            {:ok, Common.add_code(use, "import Billboard.Editor.Router", placement: :after)}

          :error ->
            {:warning, "Add `import Billboard.Editor.Router` to #{inspect(router)}."}
        end
      end
    end

    # Anywhere in the router: a site that mounted the editor itself, in
    # a live_session of its own, keeps it there.
    defp add_editor_route(zipper, session, route, router) do
      if found?(zipper, &Function.function_call?(&1, :billboard_editor, [1, 2])) do
        {:ok, zipper}
      else
        case move_to_session(zipper, session) do
          {:ok, block} ->
            {:ok, Common.add_code(block, route)}

          :error ->
            {:warning,
             "Couldn't find `live_session #{inspect(session)}` in #{inspect(router)}. Add " <>
               "`#{route}` inside the live_session your signed-in pages use, or run " <>
               "mix billboard.install again with `--live-session NAME`."}
        end
      end
    end

    @doc """
    Routes `/` to the site's `BillboardPageLive`, in place of phx.new's
    `get "/", PageController, :home`, inside phx.gen.auth's
    `live_session :current_user`: its root layout reads `@current_scope`,
    which only a LiveView in a session that mounts it has. A router that
    has a `live "/"` already is left alone.
    """
    def route_home(igniter, names) do
      {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
      line = ~s|live "/", #{names.page_live |> Module.split() |> List.last()}|

      case router && Igniter.Project.Module.find_module(igniter, router) do
        {:ok, {igniter, _source, zipper}} ->
          route_home(igniter, zipper, router, line, names)

        _ ->
          Igniter.add_warning(
            igniter,
            "Couldn't find the router. Route `/` in yours as `#{line}`, inside " <>
              "`live_session :current_user`."
          )
      end
    end

    defp route_home(igniter, zipper, router, line, names) do
      cond do
        found?(zipper, &home_live?/1) ->
          igniter

        not found?(zipper, &home_get?/1) ->
          Igniter.add_warning(
            igniter,
            "Couldn't find `get \"/\", PageController, :home` in #{inspect(router)}, so " <>
              "`/` is left as it is. To draw it with billboard, route it as `#{line}`, " <>
              "inside `live_session :current_user`, in place of the route there now."
          )

        not found?(zipper, &session?(&1, :current_user)) ->
          Igniter.add_warning(
            igniter,
            "Couldn't find `live_session :current_user` in #{inspect(router)}, so `/` is " <>
              "left as it is. Add `#{line}` inside the live_session whose `on_mount` " <>
              "assigns `current_scope`, which the root layout reads, and remove the " <>
              "`get \"/\"` route it replaces."
          )

        true ->
          igniter
          |> Igniter.Project.Module.find_and_update_module!(router, &replace_home(&1, line))
          |> Igniter.add_notice(
            "`/` is drawn by #{inspect(names.page_live)} now, in place of " <>
              "PageController's home. Remove PageController and its test once nothing " <>
              "else uses them."
          )
      end
    end

    defp replace_home(zipper, line) do
      {:ok, block} = move_to_session(zipper, :current_user)
      added = Common.add_code(block, line)
      {:ok, get} = added |> Zipper.topmost() |> Common.move_to(&home_get?/1)
      {:ok, Zipper.remove(get)}
    end

    # `/` itself: `live "/"` in `scope "/admin"` is the admin's home.
    defp home_live?(zipper) do
      Function.function_call?(zipper, :live, [2, 3, 4]) and
        Function.argument_equals?(zipper, 0, "/") and at_root?(zipper)
    end

    defp home_get?(zipper) do
      Function.function_call?(zipper, :get, 3) and Function.argument_equals?(zipper, 0, "/") and
        at_root?(zipper)
    end

    defp at_root?(zipper) do
      case Zipper.up(zipper) do
        nil ->
          true

        parent ->
          not (Function.function_call?(parent, :scope) and nested?(parent)) and at_root?(parent)
      end
    end

    defp nested?(scope) do
      Function.argument_matches_predicate?(scope, 0, fn path ->
        match?({:ok, path} when is_binary(path) and path != "/", Common.expand_literal(path))
      end)
    end

    defp session?(zipper, session) do
      Function.function_call?(zipper, :live_session, [2, 3]) and
        Function.argument_equals?(zipper, 0, session)
    end

    defp move_to_session(zipper, session) do
      with {:ok, live_session} <- Common.move_to(zipper, &session?(&1, session)) do
        Common.move_to_do_block(live_session)
      end
    end

    @doc """
    Serves the photographs billboard's editor uploads, with
    `Billboard.Plugs.UploadsStatic` just before the endpoint's
    `Plug.Static`, unless the endpoint plugs it already.
    """
    def plug_uploads(igniter, names) do
      code = """
      # Photographs uploaded in billboard's editor, from config :billboard, :uploads_dir.
      plug Billboard.Plugs.UploadsStatic
      """

      igniter
      |> Igniter.Project.Module.find_and_update_module(names.endpoint, fn zipper ->
        if found?(zipper, &plug?(&1, Billboard.Plugs.UploadsStatic)) do
          {:ok, zipper}
        else
          case Common.move_to(zipper, &plug?(&1, Plug.Static)) do
            {:ok, static} ->
              {:ok, Common.add_code(static, code, placement: :before)}

            :error ->
              {:warning,
               "Couldn't find `plug Plug.Static` in #{inspect(names.endpoint)}. Add " <>
                 "`plug Billboard.Plugs.UploadsStatic` to it, before the plug that serves " <>
                 "its static files."}
          end
        end
      end)
      |> case do
        {:ok, igniter} ->
          igniter

        {:error, igniter} ->
          Igniter.add_warning(
            igniter,
            "There's no #{inspect(names.endpoint)}. Add `plug Billboard.Plugs.UploadsStatic` " <>
              "to your endpoint, before `Plug.Static`."
          )
      end
    end

    defp plug?(zipper, module) do
      Function.function_call?(zipper, :plug, [1, 2]) and
        Function.argument_equals?(zipper, 0, module)
    end

    defp import?(zipper, module) do
      Function.function_call?(zipper, :import, [1, 2]) and
        Function.argument_equals?(zipper, 0, module)
    end

    @doc """
    Whether the config file `file` sets `key` for `app` in any `config`
    call, wherever it sits: Igniter's own lookups read only the first
    call, or only the prod block of `runtime.exs`, and a site may set it
    in a call or a block of its own.
    """
    def configures?(igniter, file, app, key) do
      path =
        igniter |> Igniter.Project.Application.config_path() |> Path.dirname() |> Path.join(file)

      igniter = Igniter.include_existing_file(igniter, path, required?: false)

      case Rewrite.source(igniter.rewrite, path) do
        {:ok, source} ->
          zipper = source |> Rewrite.Source.get(:quoted) |> Zipper.zip()
          {igniter, found?(zipper, &config?(&1, app, key))}

        _ ->
          {igniter, false}
      end
    end

    @doc "Sets `key` for `app` to `value` in `file`, unless any `config` call there sets it."
    def configure_new(igniter, file, app, key, value) do
      case configures?(igniter, file, app, key) do
        {igniter, true} -> igniter
        {igniter, false} -> Igniter.Project.Config.configure_new(igniter, file, app, [key], value)
      end
    end

    defp config?(zipper, app, key) do
      cond do
        Function.function_call?(zipper, :config, 2) ->
          Function.argument_equals?(zipper, 0, app) and
            Function.argument_matches_predicate?(
              zipper,
              1,
              &Igniter.Code.Keyword.keyword_has_path?(&1, [key])
            )

        Function.function_call?(zipper, :config, 3) ->
          Function.argument_equals?(zipper, 0, app) and Function.argument_equals?(zipper, 1, key)

        true ->
          false
      end
    end

    defp found?(zipper, pred), do: match?({:ok, _}, Common.move_to(zipper, pred))

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
