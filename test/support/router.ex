defmodule Billboard.Test.Router do
  @moduledoc """
  The test site's routes: a probe, in a signed-in `live_session`, as a
  site's admin pages are. The editor joins it, mounted as a site mounts
  it.
  """
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
