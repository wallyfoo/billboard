defmodule Billboard.Test.Router do
  @moduledoc """
  The test site's routes: a probe and the page editor, in a signed-in
  `live_session`, as a site's admin pages are, the editor mounted as a
  site mounts it.
  """
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import Billboard.Editor.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_live_flash
  end

  scope "/" do
    pipe_through :browser

    live_session :admin, on_mount: [{Billboard.Test.SignIn, :admin}] do
      live "/probe", Billboard.Test.ProbeLive
      billboard_editor "/pages", back: {"Admin", "/admin"}
    end
  end
end
