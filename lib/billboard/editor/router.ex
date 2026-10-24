defmodule Billboard.Editor.Router do
  @moduledoc """
  Mounts the page editor in a site's router, inside the `live_session`
  its signed-in admin pages use, so the editor runs that session's
  `on_mount` and has its `current_scope`. The editor acts as
  `current_scope.user`.

      import Billboard.Editor.Router

      scope "/admin", MySiteWeb.Admin do
        pipe_through [:browser, :require_authenticated_user]

        live_session :admin, on_mount: [{MySiteWeb.UserAuth, :require_authenticated}] do
          billboard_editor "/pages", back: {"Admin", "/admin"}
        end
      end

  `back` is the bar's way out: its words and where it goes, `{"Back", "/"}`
  unless given. The editor's addresses are `Billboard.Editor.path/3`'s.

  The editor checks no permission of its own: any user the
  `live_session` lets in can edit and publish every page, and the shared
  library. Mount it only in a session that admits the people who may.
  """

  @doc "Mounts the editor at `path`. See the moduledoc."
  defmacro billboard_editor(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      opts = Keyword.validate!(opts, back: {"Back", "/"})
      full = Phoenix.Router.scoped_path(__MODULE__, path)

      scope path, alias: false, as: false do
        live "/", Billboard.EditorLive, :index,
          as: :billboard_editor,
          container: {:div, class: "bb-editor"},
          metadata: %{
            billboard_editor: %{path: full, back: opts[:back]}
          }
      end
    end
  end
end
