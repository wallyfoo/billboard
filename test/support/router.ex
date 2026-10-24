defmodule Billboard.Test.Router do
  @moduledoc "The test site's routes: the editor, mounted as a site mounts it, and a probe."
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_live_flash
  end

  scope "/" do
    pipe_through :browser

    live_session :admin, on_mount: [{Billboard.Test.SignIn, :admin}] do
      live "/probe", Billboard.Test.ProbeLive
    end
  end
end
