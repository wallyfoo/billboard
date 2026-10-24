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

    @doc """
    The site's names: its app, its modules, and the modules billboard
    writes. `repo` is the site's AshPostgres repo, or nil when it has
    none. When the site has billboard already (`config :billboard, :site`
    names a module that exists, or `MySite.Billboard` does), `site` is
    that module and `pages` the domain its `use Billboard.Site` names, or
    nil when that can't be read, and `installed?` is true, so a site
    built under other names gets no second site module or domain.
    """
    def names(igniter) do
      app = Igniter.Project.Application.app_name(igniter)
      prefix = Igniter.Project.Module.module_name_prefix(igniter)
      web = Igniter.Libs.Phoenix.web_module(igniter)
      {igniter, repo} = ash_postgres_repo(igniter)

      names = %{
        app: app,
        name: app |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize(),
        prefix: inspect(prefix),
        web: inspect(web),
        site: Module.concat(prefix, Billboard),
        pages: Module.concat(prefix, Pages),
        repo: repo,
        layouts: Module.concat(web, Layouts),
        endpoint: Module.concat(web, Endpoint),
        page_live: Module.concat(web, BillboardPageLive),
        installed?: false
      }

      existing_site(igniter, names)
    end

    defp existing_site(igniter, names) do
      {igniter, configured} = config_value(igniter, "config.exs", :billboard, :site)
      configured = configured && module_of(configured)
      site = configured || names.site

      case Igniter.Project.Module.find_module(igniter, site) do
        {:ok, {igniter, _source, zipper}} ->
          pages =
            if site == names.site,
              do: site_domain(zipper) || names.pages,
              else: site_domain(zipper)

          {igniter, %{names | site: site, pages: pages, installed?: true}}

        {:error, igniter} when is_nil(configured) or configured == names.site ->
          {igniter, names}

        # The config names a site module that isn't there: write it under
        # that name, so the config and the module agree.
        {:error, igniter} ->
          igniter =
            Igniter.add_warning(
              igniter,
              "`config :billboard, :site` names #{inspect(configured)}, which the site " <>
                "doesn't define, so the installer writes it under that name. If the config " <>
                "is out of date, fix it, delete what this run wrote, and run " <>
                "mix billboard.install again."
            )

          {igniter, %{names | site: configured}}
      end
    end

    # The `domain:` of the site's `use Billboard.Site`, aliases expanded.
    defp site_domain(zipper) do
      with {:ok, body} <- Common.move_to_do_block(zipper),
           {:ok, use} <- Igniter.Code.Module.move_to_use(body, Billboard.Site),
           {:ok, opts} <- Function.move_to_nth_argument(use, 1),
           {:ok, domain} <- Igniter.Code.Keyword.get_key(opts, :domain) do
        domain |> Common.expand_alias() |> module_of()
      else
        _ -> nil
      end
    end

    defp module_of(%Zipper{node: {:__aliases__, _, parts}}) do
      if Enum.all?(parts, &is_atom/1), do: Module.concat(parts)
    end

    defp module_of(%Zipper{node: {:__block__, _, [module]}}) when is_atom(module), do: module
    defp module_of(%Zipper{node: module}) when is_atom(module) and not is_nil(module), do: module
    defp module_of(_zipper), do: nil

    # The first of the site's repos that does `use AshPostgres.Repo`.
    defp ash_postgres_repo(igniter) do
      {igniter, repos} = Igniter.Libs.Ecto.list_repos(igniter)

      Enum.reduce_while(repos, {igniter, nil}, fn repo, {igniter, nil} ->
        case ash_postgres_repo?(igniter, repo) do
          {igniter, true} -> {:halt, {igniter, repo}}
          {igniter, false} -> {:cont, {igniter, nil}}
        end
      end)
    end

    @doc "`priv/templates/DIR/NAME`, rendered with `assigns`."
    def template(dir, name, assigns) do
      :billboard
      |> :code.priv_dir()
      |> Path.join("templates/#{dir}/#{name}")
      |> EEx.eval_file(assigns: Map.to_list(assigns))
    end

    @doc """
    Writes `module` from `contents`, unless the site has it already,
    wherever it lives. It goes where Igniter puts a module of `kind` (and
    Igniter moves a new file there when it writes, whatever path it's
    given): a LiveView in `lib/MY_SITE_WEB/live/` with Igniter's Phoenix
    extension in `.igniter.exs`, and in `lib/MY_SITE_WEB/` without it. A
    file at that path that defines something else stops the run, naming
    the file to move.
    """
    def create_module(igniter, module, contents, kind \\ :source_folder) do
      case Igniter.Project.Module.module_exists(igniter, module) do
        {true, igniter} ->
          igniter

        {false, igniter} ->
          path = Igniter.Project.Module.proper_location(igniter, module, kind)

          if Igniter.exists?(igniter, path) do
            Igniter.add_issue(
              igniter,
              "#{path} is there already, and doesn't define #{inspect(module)}, which " <>
                "belongs there. Move what's in it to a file of its own, or rename the " <>
                "module it defines, then run the task again."
            )
          else
            Igniter.create_new_file(igniter, path, contents)
          end
      end
    end

    @doc """
    Writes `path` from `contents`, unless the site has it already.
    (`Igniter.create_new_file/4`'s `on_exists: :skip` skips only a file
    Igniter has read, and writes over one it hasn't.)
    """
    def create_file(igniter, path, contents) do
      if Igniter.exists?(igniter, path),
        do: igniter,
        else: Igniter.create_new_file(igniter, path, contents)
    end

    @doc """
    Appends `component` to the `components:` of the site module's
    `use Billboard.Site`, unless it's there, or says where to add it when
    there's no site module, or no `use Billboard.Site` in it to read.
    """
    def list_component(igniter, site, component) do
      igniter
      |> Igniter.Project.Module.find_and_update_module(site, fn zipper ->
        with {:ok, use} <- Igniter.Code.Module.move_to_use(zipper, Billboard.Site),
             {:ok, use} <- Function.update_nth_argument(use, 1, &add_component(&1, component)) do
          {:ok, use}
        else
          _ -> {:warning, list_it(site, component)}
        end
      end)
      |> case do
        {:ok, igniter} -> igniter
        {:error, igniter} -> Igniter.add_warning(igniter, list_it(site, component))
      end
    end

    defp add_component(answers, component) do
      Igniter.Code.Keyword.set_keyword_key(answers, :components, [component], fn list ->
        IList.append_new_to_list(list, component)
      end)
    end

    defp list_it(site, component),
      do:
        "Add #{inspect(component)} to `components:` in #{inspect(site)}'s " <>
          "`use Billboard.Site`, where the palette should offer it."

    defp ash_postgres_repo?(igniter, repo) do
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
        # Looks only inside `start/2`, so a child list elsewhere in the
        # module is neither read nor changed.
        {:ok, start} ->
          Common.within(start, &add_cache_to_start(&1, app))

        :error ->
          {:warning, "Start `Billboard.Cache` in #{inspect(app)}, after the repo and PubSub."}
      end
    end

    defp add_cache_to_start(start, app) do
      cond do
        found?(start, &Common.nodes_equal?(&1, Billboard.Cache)) ->
          {:ok, start}

        pubsub = find_pubsub(start) ->
          {:ok, Zipper.insert_right(pubsub, Sourceror.parse_string!("Billboard.Cache"))}

        true ->
          {:warning,
           "Couldn't find `{Phoenix.PubSub, …}` in #{inspect(app)}'s children. Start " <>
             "`Billboard.Cache` there yourself, after the repo and PubSub."}
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

    @doc """
    Imports the editor's router macro, and mounts the editor in the
    signed-in live_session: phx.gen.auth's, when its `on_mount` runs
    `:require_authenticated`, or the one `--live-session` names, which is
    trusted when its `on_mount` can't be read as signing in, with a
    notice saying so. Never `:current_user`, which is for everyone.
    """
    def mount_editor(igniter, opts) do
      {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
      web = Igniter.Libs.Phoenix.web_module(igniter)
      # A name typed on the command line, once, so the atom is safe.
      session = String.to_atom(opts[:live_session])
      named? = opts[:live_session] != "require_authenticated_user"
      route = ~s|billboard_editor #{inspect(opts[:editor_path])}, back: {"Home", "/"}|

      if router do
        igniter
        |> Igniter.Project.Module.find_and_update_module!(
          router,
          &import_editor_router(&1, web, router)
        )
        |> add_editor_route(router, session, named?, route)
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
    defp add_editor_route(igniter, router, session, named?, route) do
      {:ok, {igniter, _source, zipper}} = Igniter.Project.Module.find_module(igniter, router)

      cond do
        found?(zipper, &Function.function_call?(&1, :billboard_editor, [1, 2])) ->
          igniter

        not found?(zipper, &session?(&1, session)) ->
          Igniter.add_warning(
            igniter,
            "Couldn't find `live_session #{inspect(session)}` in #{inspect(router)}. Add " <>
              "`#{route}` inside the live_session your signed-in pages use, or run " <>
              "mix billboard.install again with `--live-session NAME`."
          )

        true ->
          {:ok, live_session} = Common.move_to(zipper, &session?(&1, session))

          case signing_in(live_session, session, named?) do
            :signed_in ->
              write_editor_route(igniter, router, session, route)

            :trusted ->
              igniter
              |> write_editor_route(router, session, route)
              |> Igniter.add_notice(
                "The editor is mounted in `live_session #{inspect(session)}`, as " <>
                  "`--live-session` asked, but the installer couldn't confirm it requires " <>
                  "signing in: its `on_mount` names no `require_…` hook. Everyone the " <>
                  "session lets in can edit and publish every page, so make sure only " <>
                  "signed-in admins can join it."
              )

            :refused ->
              Igniter.add_warning(igniter, refusal(router, session, route))
          end
      end
    end

    defp write_editor_route(igniter, router, session, route) do
      Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
        zipper |> move_to_session(session) |> add_route(route)
      end)
    end

    defp add_route({:ok, block}, route), do: {:ok, Common.add_code(block, route)}
    defp add_route(:error, _route), do: :error

    defp refusal(router, :current_user, route) do
      "`live_session :current_user` in #{inspect(router)} is phx.gen.auth's session for " <>
        "everyone, signed in or not, so the editor wasn't mounted there: anyone it lets in " <>
        "can edit and publish every page. Add `#{route}` inside a live_session only " <>
        "signed-in admins can join, or run mix billboard.install again with " <>
        "`--live-session NAME`."
    end

    defp refusal(router, session, route) do
      "The installer couldn't confirm `live_session #{inspect(session)}` in " <>
        "#{inspect(router)} requires signing in: its `on_mount` doesn't run " <>
        "`:require_authenticated`. Anyone the editor lets in can edit and publish every " <>
        "page, so the editor wasn't mounted. Add `#{route}` inside a live_session only " <>
        "signed-in admins can join, or run mix billboard.install again with " <>
        "`--live-session NAME`, which is trusted."
    end

    # Whether only a signed-in user can join the live_session.
    # phx.gen.auth's `:current_user` session is for everyone, whatever it
    # says. Its signed-in one runs `:require_authenticated` in its
    # `on_mount`. A scope's `pipe_through` alone isn't enough: plugs guard
    # only the first, HTTP render, while `on_mount` runs on the connected
    # mount and on every live navigation within the session too.
    # A session `--live-session` names is signed in when its `on_mount`
    # names any `require_…` hook, as `{MySiteWeb.UserAuth, :require_admin}`
    # or `MySiteWeb.RequireAdmin`, and otherwise trusted.
    defp signing_in(_live_session, :current_user, _named?), do: :refused

    defp signing_in(live_session, _session, named?) do
      on_mount =
        with {:ok, opts} <- Function.move_to_nth_argument(live_session, 1),
             {:ok, on_mount} <- Igniter.Code.Keyword.get_key(opts, :on_mount) do
          on_mount.node
        else
          _ -> nil
        end

      cond do
        not is_nil(on_mount) and mentions?(on_mount, :require_authenticated) -> :signed_in
        named? and not is_nil(on_mount) and requires_something?(on_mount) -> :signed_in
        named? -> :trusted
        true -> :refused
      end
    end

    # An `on_mount` that names a `require_…` atom, or a module whose last
    # name starts `Require`.
    defp requires_something?(ast) do
      {_ast, found?} =
        Macro.prewalk(ast, false, fn
          {:__aliases__, _, parts} = node, found ->
            last = parts |> List.last() |> to_string()
            {node, found or String.starts_with?(last, "Require")}

          atom = node, found when is_atom(atom) ->
            {node, found or String.starts_with?(Atom.to_string(atom), "require_")}

          node, found ->
            {node, found}
        end)

      found?
    end

    defp mentions?(ast, atom) do
      {_ast, found?} =
        Macro.prewalk(ast, false, fn
          {:__block__, _, [^atom]} = node, _found -> {node, true}
          ^atom = node, _found -> {node, true}
          node, found -> {node, found}
        end)

      found?
    end

    @doc """
    Writes the site's `BillboardPageLive` and routes `/` to it, in place
    of phx.new's `get "/", PageController, :home`, inside phx.gen.auth's
    `live_session :current_user`: its root layout reads `@current_scope`,
    which only a LiveView in a session that mounts it has. A router that
    has a `live "/"` already is left alone, and gets no page: one routed
    to another LiveView is noticed, so the site knows `--home` did
    nothing.
    """
    def route_home(igniter, names) do
      {igniter, router} = Igniter.Libs.Phoenix.select_router(igniter)
      line = ~s|live "/", #{names.page_live |> Module.split() |> List.last()}|

      case router && Igniter.Project.Module.find_module(igniter, router) do
        {:ok, {igniter, _source, zipper}} ->
          route_home(igniter, zipper, router, line, names)

        _ ->
          igniter
          |> write_page_live(names)
          |> Igniter.add_warning(
            "Couldn't find the router. Route `/` in yours as `#{line}`, inside " <>
              "`live_session :current_user`."
          )
      end
    end

    defp route_home(igniter, zipper, router, line, names) do
      case Common.move_to(zipper, &home_live?/1) do
        {:ok, live} -> routed_home(igniter, live, names)
        :error -> igniter |> write_page_live(names) |> replace_home(zipper, router, line, names)
      end
    end

    defp write_page_live(igniter, names),
      do:
        create_module(
          igniter,
          names.page_live,
          template("billboard.install", "page_live.ex.eex", names)
        )

    # `/` is routed already: to the visitor page, as a second run finds
    # it (which is written if it's missing), or to a LiveView of the
    # site's, which `--home` leaves alone.
    defp routed_home(igniter, live, names) do
      page_live = names.page_live |> Module.split() |> List.last()

      target =
        with {:ok, module} <- Function.move_to_nth_argument(live, 1),
             %Zipper{node: {:__aliases__, _, parts}} <- module do
          Enum.map_join(parts, ".", &to_string/1)
        else
          _ -> nil
        end

      if target && String.ends_with?("." <> target, "." <> page_live) do
        write_page_live(igniter, names)
      else
        Igniter.add_notice(
          igniter,
          "`/` is routed already#{if target, do: ", to #{target}", else: ""}, so `--home` " <>
            "wrote no page and left the route alone. To draw `/` with billboard, write a " <>
            "LiveView that draws `Billboard.Sections.page/1` and route `/` to it, or remove " <>
            "the route and run mix billboard.install --home again."
        )
      end
    end

    defp replace_home(igniter, zipper, router, line, names) do
      cond do
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
          |> Igniter.Project.Module.find_and_update_module!(router, &replace_home_get(&1, line))
          |> Igniter.add_notice(
            "`/` is drawn by #{inspect(names.page_live)} now, in place of " <>
              "PageController's home, so phx.new's test of that page, " <>
              "test/#{Macro.underscore(names.web)}/controllers/page_controller_test.exs, " <>
              "fails. Remove the test, and PageController once nothing else uses it."
          )
      end
    end

    defp replace_home_get(zipper, line) do
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
      Function.argument_matches_predicate?(scope, 0, fn arg ->
        match?({:ok, path} when path != "/", scope_path(arg))
      end)
    end

    # A scope's path, given first (`scope "/admin", …`) or as a keyword
    # (`scope path: "/admin"`).
    defp scope_path(arg) do
      case Common.expand_literal(arg) do
        {:ok, path} when is_binary(path) ->
          {:ok, path}

        _ ->
          with {:ok, path} <- Igniter.Code.Keyword.get_key(arg, :path),
               {:ok, path} when is_binary(path) <- Common.expand_literal(path) do
            {:ok, path}
          else
            _ -> :error
          end
      end
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
      {igniter, value} = config_value(igniter, file, app, key)
      {igniter, not is_nil(value)}
    end

    # The value the first `config` call in `file` that sets `key` for
    # `app` gives it, wherever the call sits, or nil.
    defp config_value(igniter, file, app, key) do
      path =
        igniter |> Igniter.Project.Application.config_path() |> Path.dirname() |> Path.join(file)

      igniter = Igniter.include_existing_file(igniter, path, required?: false)

      with {:ok, source} <- Rewrite.source(igniter.rewrite, path),
           zipper = source |> Rewrite.Source.get(:quoted) |> Zipper.zip(),
           {:ok, call} <- Common.move_to(zipper, &config?(&1, app, key)) do
        {igniter, config_arg(call, key)}
      else
        _ -> {igniter, nil}
      end
    end

    defp config_arg(call, key) do
      if Function.function_call?(call, :config, 3) do
        with {:ok, value} <- Function.move_to_nth_argument(call, 2), do: value, else: (_ -> nil)
      else
        with {:ok, opts} <- Function.move_to_nth_argument(call, 1),
             {:ok, value} <- Igniter.Code.Keyword.get_key(opts, key) do
          value
        else
          _ -> nil
        end
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

    @doc """
    Inserts each of `lines` that `path` lacks, together, after its first
    line starting with `anchor`, or, with `{:last, prefix}`, after its
    last line starting with `prefix`. With no such line, they go first,
    or, with `{:last, prefix}`, last.
    """
    def add_lines(igniter, path, anchor, lines) do
      if Igniter.exists?(igniter, path) do
        Igniter.update_file(igniter, path, fn source ->
          content = Rewrite.Source.get(source, :content)

          case Enum.reject(lines, &String.contains?(content, &1)) do
            [] ->
              source

            missing ->
              content
              |> String.split("\n")
              |> insert_lines(anchor, missing)
              |> Enum.join("\n")
              |> then(&Rewrite.Source.update(source, :content, &1))
          end
        end)
      else
        Igniter.add_warning(
          igniter,
          "There's no #{path}. Add these lines to your own:\n\n" <> Enum.join(lines, "\n")
        )
      end
    end

    defp insert_lines(existing, {:last, prefix}, missing) do
      case existing
           |> Enum.reverse()
           |> Enum.split_while(&(not String.starts_with?(&1, prefix))) do
        {_after, []} ->
          {body, trailing} = trailing_blank(existing)
          body ++ missing ++ trailing

        {after_anchor, [anchor | before]} ->
          Enum.reverse(before) ++ [anchor | missing] ++ Enum.reverse(after_anchor)
      end
    end

    defp insert_lines(existing, prefix, missing) do
      case Enum.split_while(existing, &(not String.starts_with?(&1, prefix))) do
        {before, [anchor | tail]} -> before ++ [anchor | missing] ++ tail
        {before, []} -> missing ++ before
      end
    end

    # Splits off the file's trailing blank lines, so lines added at the
    # end go before its final newline.
    defp trailing_blank(lines) do
      {blank, body} = lines |> Enum.reverse() |> Enum.split_while(&(&1 == ""))
      {Enum.reverse(body), blank}
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

    @sources ~w(sections sections.ex editor_live.ex editor_live editor)

    @doc """
    The `@source` lines that let Tailwind read the files billboard draws
    classes in, through the link `mix billboard.assets` makes: its
    sections, the page, and the editor. Never all of billboard, since
    the words in its other code and docs would build stray utilities.
    """
    def sources, do: Enum.map(@sources, &~s|@source "../vendor/billboard/lib/billboard/#{&1}";|)

    @doc """
    For `Igniter.Project.TaskAliases.modify_existing_alias/3`: puts `task`
    in an alias's list straight after `"compile"`, or first when the list
    has no `"compile"`, unless the list names `task` already.
    """
    def after_compile(zipper, task) do
      cond do
        not IList.list?(zipper) ->
          :error

        match?({:ok, _}, IList.move_to_list_item(zipper, &Common.nodes_equal?(&1, task))) ->
          {:ok, zipper}

        true ->
          case IList.move_to_list_item(zipper, &Common.nodes_equal?(&1, "compile")) do
            {:ok, compile} -> {:ok, Zipper.insert_right(compile, task)}
            :error -> IList.prepend_to_list(zipper, task)
          end
      end
    end

    @dev_server ~S"""
    [
      # In development, link billboard afresh before the Tailwind watcher
      # reads it, so a switch between a local checkout and the git
      # dependency never leaves the link pointing at the one no longer in use.
      "phx.server": if(Mix.env() == :dev, do: ["billboard.assets", "phx.server"], else: ["phx.server"])
    ]
    """

    @doc """
    Runs `mix billboard.assets` before `mix phx.server` in development,
    after `assets.deploy` in the aliases, unless the site has a
    `"phx.server"` alias already.
    """
    def add_dev_server_alias(igniter) do
      {:__block__, _, [[entry]]} = Sourceror.parse_string!(@dev_server)

      Igniter.update_elixir_file(igniter, "mix.exs", fn zipper ->
        with {:ok, aliases} <- Function.move_to_defp(zipper, :aliases, 0),
             aliases = Common.rightmost(aliases),
             true <- IList.list?(aliases) do
          cond do
            match?({:ok, _}, Igniter.Code.Keyword.get_key(aliases, :"phx.server")) ->
              {:ok, zipper}

            match?({:ok, _}, alias_named(aliases, :"assets.deploy")) ->
              {:ok, deploy} = alias_named(aliases, :"assets.deploy")
              {:ok, Zipper.insert_right(deploy, entry)}

            true ->
              IList.append_to_list(aliases, entry)
          end
        else
          _ ->
            {:warning,
             "Couldn't find the aliases in mix.exs. To link billboard afresh each time the " <>
               "development server starts, add this alias: " <>
               ~s|"phx.server": if(Mix.env() == :dev, do: ["billboard.assets", "phx.server"], | <>
               ~s|else: ["phx.server"])|}
        end
      end)
    end

    defp alias_named(aliases, name) do
      IList.move_to_list_item(aliases, fn item ->
        case Igniter.Code.Tuple.tuple_elem(item, 0) do
          {:ok, key} -> Common.nodes_equal?(key, name)
          :error -> false
        end
      end)
    end

    @js_imports ~S"""
    import {hooks as billboardHooks} from "phoenix-colocated/billboard"
    import {EditCanvas, InlineWords} from "../vendor/billboard/assets/js/billboard.js"
    """

    @colocated ~r/^(import \{hooks as colocatedHooks\} from "phoenix-colocated\/[a-z0-9_]+")$/m

    @doc """
    Imports the editor's hooks into `app.js`, after the site's own
    colocated hooks, and hands them to the LiveSocket. An `app.js` that
    imports `phoenix-colocated/billboard` anywhere is left alone, and one
    that names its hooks some other way gets a warning saying what to add.
    """
    def add_hooks(igniter) do
      path = "assets/js/app.js"

      fix =
        "Import the editor's hooks in #{path}, and add them to the LiveSocket's hooks:\n\n" <>
          @js_imports <>
          "\n    hooks: {...colocatedHooks, ...billboardHooks, EditCanvas, InlineWords}"

      if Igniter.exists?(igniter, path) do
        Igniter.update_file(igniter, path, fn source ->
          content = Rewrite.Source.get(source, :content)

          cond do
            String.contains?(content, "phoenix-colocated/billboard") ->
              source

            Regex.match?(@colocated, content) and
                String.contains?(content, "hooks: {...colocatedHooks") ->
              content
              |> String.replace(@colocated, "\\1\n" <> String.trim_trailing(@js_imports),
                global: false
              )
              |> String.replace(
                "hooks: {...colocatedHooks",
                "hooks: {...colocatedHooks, ...billboardHooks, EditCanvas, InlineWords",
                global: false
              )
              |> then(&Rewrite.Source.update(source, :content, &1))

            true ->
              {:warning, fix}
          end
        end)
      else
        Igniter.add_warning(igniter, fix)
      end
    end
  end
end
